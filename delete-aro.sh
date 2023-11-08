#!/usr/bin/bash
echo
echo -e "\e[32m----*---- Need Some Data from you ----*----\e[0m"
echo
read -p "Enter ResourceGroup Name: " RESOURCEGROUP
read -p "Enter Cluster Name: " CLUSTER
echo
echo -e "\e[32mStarting the Process of Deleting the Cluster\e[0m '$CLUSTER':"
echo "---"
if [ $(az aro list --resource-group $RESOURCEGROUP --query '[].name' -o tsv) == $CLUSTER ]; then
	az aro delete --resource-group $RESOURCEGROUP --name $CLUSTER
else
	echo -e "\e[31mCluster\e[0m '$CLUSTER' \e[31min Resource Group\e[0m '$RESOURCEGROUP' \e[31mis not present. Either the Cluster Name or Resource Group is incorrect. Please try again.\e[0m"
fi
echo
