Vagrant.configure("2") do |config|
  config.vm.hostname = "myhostname"
  config.vm.box = "perk/ubuntu-2204-arm64"
  config.vm.provider "qemu"
  
  config.ssh.username = "vagrant"
  config.ssh.password = "vagrant"

  # runs only during provisioning
  config.vm.provision "shell", inline: "echo hello from vagrant"
end