# powershell-misc
assorted powershell miscellaneia

runspacepool-example.ps1 - class based implementation of a reusable runspace pool to allow for multithreading parallel tasks - uses synchronised hash to allow for communication between threads

ELK STACK helper scripts
deploy-metricBEAT - preconfigure metricbeat.yml in the installer folder, this queries AD for online Windows Servers and installs the package if necessary