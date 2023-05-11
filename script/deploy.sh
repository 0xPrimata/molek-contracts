set -o allexport
source .env
set +o allexport

forge create --rpc-url https://rpc.ankr.com/avalanche_fuji \
    --private-key $PRIVATE_KEY \
    --etherscan-api-key $SNOWTRACE_KEY \
    --verify \
    src/Marketplace.sol:Marketplace