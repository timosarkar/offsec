Vagrant.configure("2") do |config|
  config.vm.box = "rootware/flareVm"
  config.vm.network :private_network, type: "dhcp"
  config.vm.hostname = "detonation"
  config.vm.box_check_update = true

  config.vm.provider "virtualbox" do |vb|
    vb.name = "detonation"
    vb.cpus = "2"
    vb.memory = "4096"
    vb.customize ["modifyvm", :id, "--vram", "256"]
  end
end
