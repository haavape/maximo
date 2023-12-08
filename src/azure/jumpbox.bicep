param location string
param networkInterfaceName string
param networkSecurityGroupName string
param networkSecurityGroupRules array
param subnetName string
param virtualNetworkName string
//param addressPrefixes array
//param subnets array
// param publicIpAddressName string
// param publicIpAddressType string
// param publicIpAddressSku string
param virtualMachineName string
param osDiskType string
param virtualMachineSize string
param adminUsername string
@secure()
param adminPassword string
param zone string
param applicationId string
@secure()
param applicationSecret string
param sshPubKey string
param pullSecret string
param entitlementKey string
param baseDomain string
param clusterName string
param baseDomainResourceGroup string
param vnetName string
param subnetControlNodeName string
param subnetWorkerNodeName string
param subnetEndpointsName string
param controlMachineSize string
param workerMachineSize string
param numControlReplicas string
param numWorkerReplicas string
param customInstallConfigURL string
param installMAS string
param installOCS string
param installCP4D string
param installVI string
param openshiftVersion string
param azureFilesCSIVersion string
param masChannel string
param nvidiaOperatorChannel string
param nvidiaOperatorCSV string
param branchName string

var nsgId = resourceId(resourceGroup().name, 'Microsoft.Network/networkSecurityGroups', networkSecurityGroupName)
var vnetId = resourceId(resourceGroup().name, 'Microsoft.Network/virtualNetworks', virtualNetworkName)
var subnetRef = '${vnetId}/subnets/${subnetName}'
var subscriptionId = subscription().subscriptionId
var tenantId = subscription().tenantId //tenantId() does not work
var resourceGroupName = resourceGroup().name
var cloudInitData = '#cloud-config\n\nruncmd:\n - mkdir /tmp/OCPInstall\n - mkdir ~/.azure/\n - echo \'{"subscriptionId":"${subscriptionId}","clientId":"${applicationId}","clientSecret":"${applicationSecret}","tenantId":"${tenantId}"}\' > ~/.azure/osServicePrincipal.json\n - sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc\n - |\n    echo -e "[azure-cli]\n    name=Azure CLI\n    baseurl=https://packages.microsoft.com/yumrepos/azure-cli\n    enabled=1\n    gpgcheck=1\n    gpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/azure-cli.repo\n - sudo dnf -y install azure-cli\n - [ wget, -nv, "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${openshiftVersion}/openshift-install-linux.tar.gz", -O, /tmp/OCPInstall/openshift-install-linux.tar.gz ]\n - echo "ssh-rsa ${sshPubKey}" > /tmp/id_rsa\n - mkdir /tmp/OCPInstall/QuickCluster\n - tar xvf /tmp/OCPInstall/openshift-install-linux.tar.gz -C /tmp/OCPInstall\n - |\n    export baseDomain="${baseDomain}"\n    export clusterName="${clusterName}"\n    export deployRegion="${location}"\n    export baseDomainResourceGroup="${baseDomainResourceGroup}"\n    export pullSecret=\'${pullSecret}\'\n    export sshPubKey="${sshPubKey}"\n    export ENTITLEMENT_KEY="${entitlementKey}"\n    export vnetName="${vnetName}"\n    export resourceGroupName="${resourceGroupName}"\n    export subnetControlNodeName="${subnetControlNodeName}"\n    export subnetWorkerNodeName="${subnetWorkerNodeName}"\n    export subnetPrivateEndpointName="${subnetEndpointsName}"\n    export controlMachineSize="${controlMachineSize}"\n    export workerMachineSize="${workerMachineSize}"\n    export numControlReplicas="${numControlReplicas}"\n    export numWorkerReplicas="${numWorkerReplicas}"\n    export customInstallConfigURL="${customInstallConfigURL}"\n    export installMAS="${installMAS}"\n    export installOCS="${installOCS}"\n    export installCP4D="${installCP4D}"\n    export installVI="${installVI}"\n    export azureFilesCSIVersion="${azureFilesCSIVersion}"\n    export masChannel="${masChannel}"\n    export branchName="${branchName}"\n    export nvidiaOperatorChannel="${nvidiaOperatorChannel}"\n    export nvidiaOperatorCSV="${nvidiaOperatorCSV}"\n - [ wget, -nv, "https://raw.githubusercontent.com/haavape/maximo/${branchName}/src/installers/install_config.sh", -O, /tmp/install_config.sh ]\n - chmod +x /tmp/install_config.sh\n - sudo -E /tmp/install_config.sh\n'


resource networkInterfaceName_resource 'Microsoft.Network/networkInterfaces@2018-10-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetRef
          }
          privateIPAllocationMethod: 'Dynamic'
          // publicIPAddress: {
          //   id: resourceId(resourceGroup().name, 'Microsoft.Network/publicIpAddresses', publicIpAddressName)
          // }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsgId
    }
  }
  dependsOn: [
    networkSecurityGroupName_resource
    //publicIpAddressName_resource
  ]
}

resource networkSecurityGroupName_resource 'Microsoft.Network/networkSecurityGroups@2019-02-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: networkSecurityGroupRules
  }
}

// resource virtualNetworkName_resource 'Microsoft.Network/virtualNetworks@2020-11-01' = {
//   name: virtualNetworkName
//   location: location
//   properties: {
//     addressSpace: {
//       addressPrefixes: addressPrefixes
//     }
//     subnets: subnets
//   }
// }

// resource publicIpAddressName_resource 'Microsoft.Network/publicIpAddresses@2019-02-01' = {
//   name: publicIpAddressName
//   location: location
//   properties: {
//     publicIPAllocationMethod: publicIpAddressType
//   }
//   sku: {
//     name: publicIpAddressSku
//   }
//   zones: [
//     zone
//   ]
// }

resource virtualMachineName_resource 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: virtualMachineName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: virtualMachineSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
      imageReference: {
        publisher: 'RedHat'
        offer: 'RHEL'
        sku: '8_4'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceName_resource.id
        }
      ]
    }
    osProfile: {
      computerName: virtualMachineName
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: base64(cloudInitData)
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
  zones: [
    zone
  ]
}
