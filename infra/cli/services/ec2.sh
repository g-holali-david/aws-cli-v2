#!/bin/bash
VPC_ID="vpc-0ebcdb39f7a526ef9"

create_nacl() {
    local nacl_name="$1"
    aws_response=$(aws ec2 create-network-acl \
        --vpc-id "$VPC_ID" \
        --tag-specifications "ResourceType=network-acl,Tags=[{Key=Name,Value=$nacl_name}]")

    echo "$aws_response" > nacl.json
}

delete_nacl() {
    local nacl_id="$1"
    aws ec2 delete-network-acl --network-acl-id "$nacl_id"
}

create_ingress_rule() {
    local network_acl_id="$1"
    local rule_number="$2"
    # si il n'y a pas d'argument $3 alors la valeur par défaut sera 6
    local protocol=${3:-6}
    local from=${4:-443}
    local to=${5:-443}
    local rule_action=${6:-"deny"}
    aws ec2 create-network-acl-entry \
        --network-acl-id "$network_acl_id" \
        --rule-number "$rule_number" \
        --protocol "$protocol" \
        --port-range From="$from",To="$to" \
        --cidr-block 0.0.0.0/0 \
        --rule-action "$rule_action" \
        --ingress
}

# 1. Création de la NACL (la réponse est stockée dans nacl.json)
create_nacl "$1"

# 2. Récupération du NetworkAclId depuis nacl.json
nacl_id=$(jq -r '.NetworkAcl.NetworkAclId' nacl.json)

# 3. Passage de cette valeur à la fonction de création de la règle entrante
create_ingress_rule "$nacl_id" 100
