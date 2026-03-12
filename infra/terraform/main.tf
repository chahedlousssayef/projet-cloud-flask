# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Réseau virtuel
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-flask-app"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "subnet-flask-app"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# IP publique
resource "azurerm_public_ip" "pip" {
  name                = "pip-flask-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Groupe de sécurité réseau (NSG)
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-flask-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

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

# Interface réseau
resource "azurerm_network_interface" "nic" {
  name                = "nic-flask-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id           = azurerm_public_ip.pip.id
  }
}

# Association NSG / NIC
resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Machine virtuelle Ubuntu 22.04
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

# Stockage Azure Blob
resource "azurerm_storage_account" "storage" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type  = "LRS"
  min_tls_version          = "TLS1_2"
  allow_nested_items_to_be_public = false
}

resource "azurerm_storage_container" "container" {
  name                  = var.storage_container_name
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

# Données pour Ansible (inventaire)
data "template_file" "inventory" {
  template = file("${path.module}/templates/inventory.tpl")
  vars = {
    vm_public_ip = azurerm_linux_virtual_machine.vm.public_ip_address
    admin_user   = var.admin_username
  }
}

# Fichier inventory généré (optionnel, pour Ansible local)
resource "local_file" "inventory" {
  content  = data.template_file.inventory.rendered
  filename = "${path.module}/../ansible/inventory/hosts.yml"
}

# Provisioning Ansible après création de la VM
resource "null_resource" "ansible" {
  depends_on = [
    azurerm_linux_virtual_machine.vm,
    azurerm_storage_account.storage,
    azurerm_storage_container.container,
    local_file.inventory,
  ]

  triggers = {
    vm_id = azurerm_linux_virtual_machine.vm.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      sleep 30
      cd ${path.module}/../ansible && \
      ansible-playbook -i inventory/hosts.yml playbooks/bootstrap.yml playbooks/deploy.yml \
        -e "storage_account_name=${azurerm_storage_account.storage.name}" \
        -e "storage_account_key=${azurerm_storage_account.storage.primary_access_key}" \
        -e "storage_container_name=${azurerm_storage_container.container.name}" \
        -e "postgres_password=${var.postgres_password}" \
        -e "postgres_user=${var.postgres_user}" \
        -e "postgres_db=${var.postgres_db}" \
        -e "repo_url=${var.repo_url}" \
        -e "repo_branch=${var.repo_branch}" \
        -e "ssh_private_key_path=${pathexpand(var.ssh_private_key_path)}" \
        --private-key=${pathexpand(var.ssh_private_key_path)}
    EOT
    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
    }
  }
}
