{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    pkgs.vagrant
    pkgs.qemu
  ];

  shellHook = ''
   vagrant plugin install vagrant-qemu
   vagrant up
   vagrant ssh 
  '';
}
