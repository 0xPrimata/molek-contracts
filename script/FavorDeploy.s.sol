// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "forge-std/Test.sol";
import "../src/MolekMarket.sol";
import "../src/utils/WrappedToken.sol";
import "../src/interfaces/IMarketplace.sol";
import "../src/Favor.sol";
import "forge-std/Script.sol";

contract FavorTestnet is Script {
    Favor public favor;

    address public wavaxFuji = 0x1D308089a2D1Ced3f1Ce36B1FcaF815b07217be3;
    address public wavax = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address public weth = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    address public lzEndpointAvax = 0x3c2269811836af69497E5F486A85D7316753cf62;
    address public lzEndpointFuji = 0x93f54D755A063cE7bB9e6Ac47Eccc8e33411d706;
    address public lzEndpointGoerli =
        0xbfD2135BFfbb0B5378b56643c2Df8a87552Bfa23;

    uint256 public deployerPrivateKey = vm.envUint("FAVOR_KEY");

    function run() external {
        vm.startBroadcast(deployerPrivateKey);
        address wrappedToken = block.chainid == 43113
            ? wavaxFuji
            : block.chainid == 5
            ? weth
            : wavax;
        address lzEndpoint = block.chainid == 43113
            ? lzEndpointFuji
            : block.chainid == 5
            ? lzEndpointGoerli
            : lzEndpointAvax;

        favor = new Favor(
            0x441d636cd482769c6581B4062e931f13aB5dA774,
            lzEndpoint
        );
        vm.stopBroadcast();
    }
}
