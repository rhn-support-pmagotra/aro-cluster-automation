#!/usr/bin/bash
#
echo
echo -e "\e[32m----*---- Need Some Data from you ----*----\e[0m"
echo
echo -e "\e[32mMake Sure to Download the Pull Secrets from\e[0m https://console.redhat.com/openshift/install/azure/aro-provisioned"
echo -e "\e[32mBefore Proceeding Further with the Setup\e[0m"
read -p "Enter AZ Account email: " AZEMAIL
read -p "Enter Region: " REGION
read -p "Enter Subscription [Press Enter to Pick Default]: " subs_value
subs_fetch=${subs_value:-3ceade1e-a7eb-4b2d-ba84-f84f89a10267}
read -p "Enter ResourceGroup Name: " RESOURCEGROUP
read -p "Virtual Network Name: " VNETNAME
read -p "Virtual Network Address Prefix: " VNETADDR
read -p "Enter Cluster Name: " CLUSTER
echo


# ----


echo -e "\e[32mLogging in to Azure CLI\e[0m"
echo "---"
sleep 1s
if [ $(az account show --query 'user.name' -o tsv) == $AZEMAIL ]; then
        echo "Account $AZMAIL is already logged in"
else
        az login
fi
echo


# -----


echo -e "\e[32mChecking Available Limit for the VM:\e[0m"
echo "---"
sleep 1s
for LIMIT in $(az vm list-usage -l $REGION  --query "[?contains(name.value, 'standardDSv3Family')]" -otable | awk 'NR==3 {print $2}')
do
    if [ "$LIMIT" -ge 200 ]; then
        echo "Current limit is $LIMIT. Proceeding further safely"
    else
        echo "Current limit it is below 200. Script will now exit."
        exit 1
    fi
done
echo

# -----


echo -e "\e[32mSetting-up the Subscription:\e[0m"
echo "---"
sleep 1s
subs_fetch_from_user=$(echo "$subs_fetch" | tr -d '[:space:]')
current_subs_from_az=$(az account list --query "[?isDefault].id" -o tsv)
if [ "$current_subs_from_az" == "$subs_fetch_from_user" ]; then
    echo "Subscription is already set"
else
    if [ "$subs_fetch_from_user" == "desired_value" ]; then
        echo "Subscription set to the desired value $subs_fetch_from_user."
        az account set --subscription "$subs_fetch_from_user"
    else
        echo -e "\e[31mInvalid subscription value provided\e[0m '$subs_fetch_from_user'\e[31m. Script will exit now.\e[0m"
	exit 1
    fi
fi
echo


# -----


echo -e "\e[32mRegistering Providers:\e[0m"
echo "---"
sleep 1s
if [[ $(az provider list --query "[?namespace=='Microsoft.RedHatOpenShift'].namespace" | grep -o "Microsoft.RedHatOpenShift") == "Microsoft.RedHatOpenShift" ]]; then
        echo "Provider Microsoft.RedHatOpenShift is already Registered"
else
        az provider register -n Microsoft.RedHatOpenShift --wait
        echo "Done Registering Microsoft.RedHatOpenShift"
fi

#---

echo "---"
if [[ $(az provider list --query "[?namespace=='Microsoft.Compute'].namespace" | grep -o "Microsoft.Compute") == "Microsoft.Compute" ]]; then
        echo "Provider Microsoft.Compute is already Registered"
else
        az provider register -n Microsoft.Compute --wait
        echo "Done Registering Microsoft.Compute"
fi

#---

echo "---"
if [[ $(az provider list --query "[?namespace=='Microsoft.Storage'].namespace" | grep -o "Microsoft.Storage") == "Microsoft.Storage" ]]; then
        echo "Provider Microsoft.Storage is already Registered"
else
        az provider register -n Microsoft.Storage --wait
        echo "Done Registering Microsoft.Storage"
fi

#---

echo "---"
if [[ $(az provider list --query "[?namespace=='Microsoft.Authorization'].namespace" | grep -o "Microsoft.Authorization") == "Microsoft.Authorization" ]]; then
        echo "Provider Microsoft.Authorization is already Registered"
else
        az provider register -n Microsoft.Authorization --wait
        echo "Done Registering Microsoft.Authorization"
fi
echo


# -----


echo -e "\e[32mCreate Resource Group\e[0m $RESOURCEGROUP:"
echo "---"
sleep 1s
if [[ $(az group exists -n $RESOURCEGROUP) == "true" ]]; then
	echo "Resource Group $RESOURCEGROUP is already present"
else
	az group create --name $RESOURCEGROUP --location $REGION
fi
echo


# -----


echo -e "\e[32mCreating Virtual Network\e[0m $VNETNAME"
echo "---"
sleep 1s
if az network vnet show --resource-group $RESOURCEGROUP --name $VNETNAME --query 'name' -o json | grep -q "$VNETNAME"; then
	echo "Network $VNETNAME already Present"
else
	az network vnet create --resource-group $RESOURCEGROUP --name $VNETNAME --address-prefixes $VNETADDR
fi
echo


# -----


echo -e "\e[32mCreating master subnet:\e[0m"
echo "---"
sleep 1s
if az network vnet subnet list --resource-group $RESOURCEGROUP --vnet-name $VNETNAME --query '[].name' -o json | jq -r '.[0]' | grep  "master-subnet" >> /dev/null; then
	echo "Network master-subnet already Present"
else
	az network vnet subnet create --resource-group $RESOURCEGROUP --vnet-name $VNETNAME --name master-subnet --address-prefixes 10.0.0.0/23
fi
echo


# -----


echo -e "\e[32mCreate worker subnet:\e[0m"
echo "---"
sleep 1s
if az network vnet subnet list --resource-group $RESOURCEGROUP --vnet-name $VNETNAME --query '[].name' -o json | jq -r '.[1]' | grep  "worker-subnet" >> /dev/null; then
	echo "Network worker-subnet already Present"
else
	az network vnet subnet create --resource-group $RESOURCEGROUP --vnet-name $VNETNAME --name worker-subnet --address-prefixes 10.0.2.0/23 
fi
echo


# -----


echo -e "\e[32mChecking the availability of Pull Secret File\e[0m"
echo "---"
sleep 1s
if [ -e "pull-secret.txt" ]; then
    echo "File 'pull-secret.txt' is present in the current directory."
else
    echo -e "pull-secret.txt \e[31mfile is missing. Please Download the Pull Secrets from\e[0m https://console.redhat.com/openshift/install/azure/aro-provisioned\e[31m. Script will now Exit.\e[0m"
    exit 1
fi
echo


# -----


echo -e "\e[32mStarting Cluster Creation with the name\e[0m $CLUSTER:"
echo "---"
sleep 1s

if [ $(az aro list --resource-group pmagotra-rg --query '[].name' -o tsv) == $CLUSTER ]; then
	echo "Cluster $CLUSTER already exists"
else
	az aro create --resource-group $RESOURCEGROUP --name $CLUSTER --vnet $VNETNAME --master-subnet master-subnet --worker-subnet worker-subnet --pull-secret @pull-secret.txt
fi
echo


# -----


echo -e "\e[32mShowing the Installed Cluster Details\e[0m"
echo "---"
sleep 1s
echo -e "   \e[32mConsole URL:\e[0m $(az aro show -n $CLUSTER -g $RESOURCEGROUP --query "consoleProfile.url" -otsv)"
echo -e "       \e[32mAPI URL:\e[0m $(az aro show -g $RESOURCEGROUP -n $CLUSTER --query "apiserverProfile.url" -otsv)"
echo -e "\e[32mkubeAdmin User:\e[0m $(az aro list-credentials -n $CLUSTER -g $RESOURCEGROUP | jq -r '.kubeadminUsername')"
echo -e "\e[32mkubeAdmin Pass:\e[0m $(az aro list-credentials -n $CLUSTER -g $RESOURCEGROUP | jq -r '.kubeadminPassword')"
echo -e "\e[32m---------------------\e[0m"
echo
echo -e "\e[32mComplete Login Command:\e[0m oc login -u $(az aro list-credentials -n $CLUSTER -g $RESOURCEGROUP | jq -r '.kubeadminUsername') -p $(az aro list-credentials -n $CLUSTER -g $RESOURCEGROUP | jq -r '.kubeadminPassword') $(az aro show -g $RESOURCEGROUP -n $CLUSTER --query apiserverProfile.url -otsv)"


# -----
