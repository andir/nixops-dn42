{
  boolean = let
      ipv4 = "148.251.9.69";
      ipv6 = "2a01:4f8:201:6344::2";
      ipv4cidr = "${ipv4}/27";
      ipv6cidr = "${ipv6}/64";
      ipv4gw = "148.251.9.65";
      ipv6gw = "fe80::1";
      dnsServers = [
        "213.133.98.98" "213.133.99.99" "213.133.100.100"
        "2a01:4f8:0:a0a1::add:1010" "2a01:4f8:0:a102::add:9999" "2a01:4f8:0:a111::add:9898"
      ];
      robotUser = "#470258+KpxSc";
    in
    {
    deployment.targetEnv = "hetzner";
    deployment.hetzner.mainIPv4 = ipv4;
    deployment.hetzner.robotUser = robotUser;
    deployment.hetzner.createSubAccount = false;

    deployment.hetzner.partitions = ''
      clearpart --all --initlabel --drives=sda,sdb

      part swap1 --recommended --label=swap1 --fstype=swap --ondisk=sda
      part swap2 --recommended --label=swap2 --fstype=swap --ondisk=sdb

      part btrfs.1 --grow --ondisk=sda
      part btrfs.2 --grow --ondisk=sdb

      btrfs / --data=1 --metadata=1 --label=root btrfs.1 btrfs.2
    '';
    powerManagement.cpuFreqGovernor = null;
    hardware.cpu.intel.updateMicrocode = true;
    systemd.network.networks."10-eth0" = {
      matchConfig = {
        MACAddress = "d4:3d:7e:f8:f0:67";
      };
      address = [ ipv4cidr ipv6cidr ];
      gateway = [ ipv4gw ipv6gw ];
      dns = dnsServers;
    };
  };
}
