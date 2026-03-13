resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "time_sleep" "wait_for_rg" {
  depends_on      = [azurerm_resource_group.rg]
  create_duration = "30s"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-flask-app"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  depends_on          = [time_sleep.wait_for_rg]
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-flask-app"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "pip" {
  name                = "pip-flask-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on          = [time_sleep.wait_for_rg]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-flask-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  depends_on          = [time_sleep.wait_for_rg]

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Flask"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.flask_port)
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "nic" {
  name                = "nic-flask-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = var.vm_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

resource "azurerm_storage_account" "storage" {
  name                            = var.storage_account_name
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  depends_on                      = [time_sleep.wait_for_rg]
}

resource "azurerm_storage_container" "container" {
  name                  = var.storage_container_name
  storage_account_id    = azurerm_storage_account.storage.id
  container_access_type = "private"
}

resource "local_file" "inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    vm_public_ip         = azurerm_linux_virtual_machine.vm.public_ip_address
    admin_user           = var.admin_username
    ssh_private_key_path = pathexpand(var.ssh_private_key_path)
  })
  filename = "${path.module}/../ansible/inventory/hosts.yml"
}

resource "time_sleep" "wait_for_vm" {
  depends_on      = [azurerm_linux_virtual_machine.vm]
  create_duration = "30s"
}

resource "null_resource" "ansible" {
  depends_on = [
    time_sleep.wait_for_vm,
    azurerm_storage_account.storage,
    azurerm_storage_container.container,
    local_file.inventory,
  ]

  triggers = {
    vm_id = azurerm_linux_virtual_machine.vm.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      ansible-playbook -i inventory/hosts.yml \
        playbooks/bootstrap.yml playbooks/deploy.yml \
        -e "storage_account_name=${azurerm_storage_account.storage.name}" \
        -e "storage_account_key=${azurerm_storage_account.storage.primary_access_key}" \
        -e "storage_container_name=${azurerm_storage_container.container.name}" \
        -e "postgres_password=${var.postgres_password}" \
        -e "postgres_user=${var.postgres_user}" \
        -e "postgres_db=${var.postgres_db}" \
        -e "repo_url=${var.repo_url}" \
        -e "repo_branch=${var.repo_branch}" \
        --private-key=${pathexpand(var.ssh_private_key_path)}
    EOT
    interpreter = ["bash", "-c"]
    working_dir = "${path.module}/../ansible"
    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
    }
  }
}
