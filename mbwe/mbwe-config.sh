# ****************************************
# CONFIGURE YOUR DISK HERE
# ****************************************
# By Krzysztof Przygoda
# http://www.iknowsomething.com
# with help of http:/mybookworld.wikidot.com
# 2011-10-25
# ****************************************

# Find your disk system label under Ubuntu in System > Administration > Disk Utility
# If you boot Ubuntui 10.10 from cd it should be sdc

DISK_LABEL=sdc

# ****************************************
# For serial see label under MBWE case, for example S/N:WU2NC116047C

MBWE_SERIAL=WU2NC116047C

# ****************************************
# Choose your MBWE model:
# MBWE_MODEL=WDH1NC #for MBWE 1 disk version
# MBWE_MODEL=WDH2NC #for MBWE II 2 disks RAID version

MBWE_MODEL=WDH1NC

# ****************************************
# For MAC address see label under MBWE case

MAC_ADDRS="00:00:00:00:00:00"

# ****************************************
# You don't have to specify disk size.
# Your DataVolume will always be set to the maximum disk size
