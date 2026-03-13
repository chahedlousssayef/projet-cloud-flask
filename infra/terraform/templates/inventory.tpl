all:
  hosts:
    flask_vm:
      ansible_host: ${vm_public_ip}
      ansible_user: ${admin_user}
      ansible_ssh_private_key_file: ${ssh_private_key_path}
