// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "forge-std/Test.sol";
import "../src/MolekMarket.sol";
import "../src/utils/WrappedToken.sol";
import "../src/interfaces/IMarketplace.sol";
import "../src/Favor.sol";
import "forge-std/console.sol";

contract MarketTest is Test, IMarketplace, IERC721Receiver {
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    error TransferFromIncorrectOwner();
    error ERC721InsufficientApproval();

    TransparentUpgradeableProxy public market =
        TransparentUpgradeableProxy(
            payable(0x441d636cd482769c6581B4062e931f13aB5dA774)
        );
    MolekMarket public marketplaceImplementation =
        MolekMarket(0xe758803c864B3f17faDfbECab50F419faEbB73f1);
    ProxyAdmin public proxyAdmin =
        ProxyAdmin(0x5CE40EAC1566377E00Ef2813e671234090220Ef6);
    WrappedToken public wrappedToken =
        WrappedToken(payable(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7));
    MolekMarket public marketplace =
        MolekMarket(0x441d636cd482769c6581B4062e931f13aB5dA774);
    Favor public favor;
    address public lzEndpoint = 0x3c2269811836af69497E5F486A85D7316753cf62;

    uint256 public minPrice = 10001;
    address public feeCollector = 0x90FB67b45d73e8f6f24C1FA1aB0d21a972DbE0AE;
    address public predator = address(1337);

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function setUp() public {
        favor = new Favor(
            0x441d636cd482769c6581B4062e931f13aB5dA774,
            lzEndpoint
        );
    }

    function testBuying() public {
        marketplace.acceptAsk{value: 5000000000000000000}(
            IERC721(0x048c939bEa33c5dF4d2C69414B9385d55b3bA62E),
            199,
            0
        );
        marketplace.acceptAsk{value: 7000000000000000000}(
            IERC721(0xb6168bd82410FdcBA31cFBECadB705B63f5376D1),
            131,
            0
        );
        marketplace.acceptAsk{value: 15000000000000000000}(
            IERC721(0xb6168bd82410FdcBA31cFBECadB705B63f5376D1),
            278,
            0
        );
    }

    function testMintFavor() public {
        testBuying();
        address[] memory collections = new address[](3);
        collections[0] = 0x048c939bEa33c5dF4d2C69414B9385d55b3bA62E;
        collections[1] = 0xb6168bd82410FdcBA31cFBECadB705B63f5376D1;
        collections[2] = 0xb6168bd82410FdcBA31cFBECadB705B63f5376D1;

        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 199;
        tokenIds[1] = 131;
        tokenIds[2] = 278;

        address[] memory wrongCollections = new address[](3);
        wrongCollections[0] = 0x048c939bEa33c5dF4d2C69414B9385d55b3bA62E;
        wrongCollections[1] = 0x048c939bEa33c5dF4d2C69414B9385d55b3bA62E;
        wrongCollections[2] = 0xb6168bd82410FdcBA31cFBECadB705B63f5376D1;

        uint256[] memory wrongTokenIds = new uint256[](3);
        wrongTokenIds[0] = 199;
        wrongTokenIds[1] = 131;
        wrongTokenIds[2] = 279;

        vm.expectRevert(0x59c896be);
        favor.mint(address(this), collections, tokenIds);

        vm.expectRevert(0x59c896be);
        favor.mint(address(this), wrongCollections, wrongTokenIds);

        vm.expectRevert(0x59c896be);
        favor.mint(address(this), wrongCollections, tokenIds);

        vm.expectRevert(0x59c896be);
        favor.mint(address(this), collections, wrongTokenIds);

        vm.prank(predator);
        vm.expectRevert(NotOwnerOfTokenId.selector);
        favor.mint(address(this), collections, tokenIds);

        IERC721(collections[0]).setApprovalForAll(address(favor), true);
        vm.expectRevert("ERC721: caller is not token owner nor approved");
        favor.mint(address(this), collections, tokenIds);

        IERC721(collections[1]).setApprovalForAll(address(favor), true);
        vm.prank(predator);
        vm.expectRevert(NotOwnerOfTokenId.selector);
        favor.mint(address(this), collections, tokenIds);

        vm.expectEmit(false, false, false, false);
        emit Transfer(address(0), address(this), collections.length * 1e18);
        favor.mint(address(this), collections, tokenIds);

        vm.expectRevert(NotOwnerOfTokenId.selector);
        favor.mint(address(this), collections, tokenIds);

        assertTrue(favor.balanceOf(address(this)) == 3 * 1e18);
    }
}
