# icp-ce-installer

A single command installer for IBM ICP (IBM Cloud Private) Community Edition. This installer will create an instance
of ICP-CE on a single node virtual server. This environment is intended for development and testing of ICP driven containers and applications. 

### Requirements

- Operating System: Ubuntu 16.04x 
- Virtual Server Specs: 16 Core x 32GB RAM x 25GB Storage

### Notes

This installer has only been tested with SoftLayer VSI's but should work with any virtual server or bare metal device.

### How to use this installer

**Run the following command as root**

```
curl https://raw.githubusercontent.com/bmcsheehy/icp-ce-installer/master/install.sh | bash
```
