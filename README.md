# Dune Awakening self hosted server port
Porting the game server to run in Ubuntu or Windows WSL avoiding the need for VMs.
The purpose is to make it possible to deploy the kubernetes server app in a Linux machine directly without the need to use Hyper-V VM provided by the game developer.
This also should open other possibilties to host the server in other kubernetes PAAS services, e.g. AKS, AWS and GCP.

## Suppoerted Systems
Script is tested in Windows WSL - Ubuntu destro. However could work with other distros that uses systemd service manager.

## Suported Features
- Script supports server (Battlegroup) installation, then you can use battlegroup.sh script in the sever's download folder to start/stop/status check the battlegroups.
- Filebrowser service, when installed in WSL, should be accessible through http://localhost:18888 from your machine (that the game server is installed on).
- The expermental swap feature in the battlegroup.sh script is not suppoert at the moment.
- Services tested only as a solo/single player, further configuration on you machine and/or router may be needed to allow other players (on local network or public) to join your server

## Requirements
- Windows 10 machine with WSL enabled. Ubuntu (Linux distro with systemd service manager) should be fine, though not tested.
- k3s and steamcmd installed. when using WSL, ensure they are installed in WSL.
- Game maps rely on a custom sheduler, memory-focused-scheduler. The script takes care of its configuration if you have k3s installation without any custom configuration. If you do, you will need to check the configs under ```all_k3s_resources/k3s_configs``` and incorporate it with your cluster configs.

## How to use
### Windows
1. Clone the repo to your 
2. ensure k3s and steamcmd are installed (they must be installed in WSL)
3. Open a windows terminal and run ```wsl``
4. Navigate to the repo's folder
5. run ```./dune-server-setup.sh -h``` to see available options. First time, run ```./dune-server-setup.sh -s``` to download/update game server files from Steam.
6. Follow the script instructions. it will ask for self hosted token that is generated from our account page https://account.duneawakening.com/