// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "forge-std/Test.sol";
import "../src/Marketplace.sol";
import "../src/utils/WrappedToken.sol";
import {TransferManager} from "../src/TransferManager.sol";
import "../src/interfaces/IMarketplace.sol";

contract MockERC721 is ERC721 {
    constructor(
        string memory name,
        string memory token,
        uint256 mintAmount,
        address receiver
    ) ERC721(name, token) {
        for (uint256 i = 0; i < mintAmount; i++) {
            _mint(receiver, i);
        }
    }
}

contract MarketTest is Test, IMarketplace {
    TransparentUpgradeableProxy public market;
    Marketplace public marketplaceImplementation;
    ProxyAdmin public proxyAdmin;
    TransferManager public transferManager;
    WrappedToken public wrappedToken;
    Marketplace public marketplace;
    MockERC721 public blacklisted;
    MockERC721 public notBlacklisted;

    uint256 public minPrice = 10001;
    address public feeCollector;
    address public malicious = address(0x1337);

    function setUp() public {
        marketplaceImplementation = new Marketplace();
        proxyAdmin = new ProxyAdmin();
        feeCollector = address(0x1);
        wrappedToken = new WrappedToken();
        blacklisted = new MockERC721("blacklisted", "BL", 3, address(this));
        notBlacklisted = new MockERC721(
            "notBlacklisted",
            "NBL",
            3,
            address(this)
        );

        market = new TransparentUpgradeableProxy(
            address(marketplaceImplementation),
            address(proxyAdmin),
            abi.encodeWithSignature(
                "initialize(address,address)",
                feeCollector,
                address(wrappedToken)
            )
        );
        transferManager = new TransferManager(address(market));
        marketplace = Marketplace(address(market));
    }

    function testDeploy() public {
        assertTrue(address(market) != address(0x0));
        assertTrue(address(marketplaceImplementation) != address(0x0));

        assertTrue(marketplace.feeCollector() == feeCollector);
        assertTrue(marketplace.owner() == address(this));
    }

    function testFeeCollector() public {
        marketplace.changeFeeCollector(payable(address(0x2)));
        assertTrue(marketplace.feeCollector() == address(0x2));
        assertTrue(marketplace.owner() == address(this));
        assertTrue(marketplace.feeCollector() != address(0x1));
    }

    function testTransferManager() public {
        marketplace.changeTransferManager(address(transferManager));

        vm.prank(address(0x1337));
        vm.expectRevert("Ownable: caller is not the owner");
        marketplace.changeTransferManager(address(0x1337));

        vm.expectRevert(ZeroAddress.selector);
        marketplace.changeTransferManager(address(0x0));

        marketplace.changeTransferManager(address(0x1337));
    }

    function createAsk(address token, uint8 tokenId, uint256 price) public {
        IERC721[] memory tokens = new IERC721[](1);
        tokens[0] = IERC721(token);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        uint256[] memory prices = new uint256[](1);
        prices[0] = price;
        marketplace.createAsk(tokens, tokenIds, prices);
    }

    function cancelAsk(address token, uint8 tokenId) public {
        IERC721[] memory tokens = new IERC721[](1);
        tokens[0] = IERC721(token);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        marketplace.cancelAsks(tokens, tokenIds);
    }

    function testBlacklisted() public {
        vm.expectRevert(NotBlacklisted.selector);
        createAsk(address(notBlacklisted), 1, minPrice);

        vm.expectRevert(NotBlacklisted.selector);
        createAsk(address(blacklisted), 1, minPrice);

        vm.expectEmit(true, true, false, false);
        emit IMarketplace.Blacklisted(address(blacklisted), true);
        marketplace.blacklist(address(blacklisted), true);

        vm.expectRevert(PriceTooLow.selector);
        createAsk(address(blacklisted), 1, 1);

        vm.expectEmit(true, true, true, false);
        emit IMarketplace.CreateAsk(
            address(blacklisted),
            address(this),
            1,
            minPrice
        );
        createAsk(address(blacklisted), 1, minPrice);

        vm.expectRevert(NotBlacklisted.selector);
        createAsk(address(notBlacklisted), 1, minPrice);
    }

    function testCreateAsk() public {
        testBlacklisted();
        vm.expectRevert(NotBlacklisted.selector);
        createAsk(address(0x0), 1, minPrice);

        (bool exists, address seller, uint256 price) = marketplace.asks(
            address(blacklisted),
            1
        );
        assertTrue(exists);
        assertTrue(seller == address(this));
        assertTrue(price == minPrice);

        vm.expectEmit(true, true, true, false);
        emit IMarketplace.CreateAsk(
            address(blacklisted),
            address(this),
            1,
            minPrice * 2
        );
        createAsk(address(blacklisted), 1, minPrice * 2);
        (bool exists1, address seller1, uint256 price1) = marketplace.asks(
            address(blacklisted),
            1
        );
        assertTrue(exists1);
        assertTrue(seller1 == address(this));
        assertTrue(price1 == minPrice * 2);

        vm.expectRevert(NotOwnerOfTokenId.selector);
        vm.prank(malicious);
        createAsk(address(blacklisted), 1, minPrice);

        // outer boundary
        vm.expectRevert("ERC721: invalid token ID");
        createAsk(address(blacklisted), 4, minPrice);
    }

    function testCancelAsk() public {
        testCreateAsk();
        vm.expectEmit(true, true, false, false);
        emit IMarketplace.CancelAsk(address(blacklisted), 1);
        cancelAsk(address(blacklisted), 1);
        (bool exists, address seller, uint256 price) = marketplace.asks(
            address(blacklisted),
            1
        );
        assertTrue(!exists);
        assertTrue(seller == address(0x0));
        assertTrue(price == 0);

        createAsk(address(blacklisted), 1, minPrice);

        vm.prank(malicious);
        vm.expectRevert(NotAskCreator.selector);
        cancelAsk(address(blacklisted), 1);

        // outer boundary
        vm.expectRevert(NotAskCreator.selector);
        cancelAsk(address(blacklisted), 4);

        vm.expectRevert(NotAskCreator.selector);
        cancelAsk(address(blacklisted), 2);
    }

    function testAcceptAsk() public {
        testCreateAsk();

        wrappedToken.balanceOf(address(this));

        vm.expectRevert(AskDoesNotExist.selector);
        marketplace.acceptAsk(blacklisted, 0, minPrice * 2);

        vm.expectRevert("ERC721: caller is not token owner or approved");
        marketplace.acceptAsk{value: minPrice * 2}(blacklisted, 1, 0);

        blacklisted.approve(address(marketplace), 1);

        vm.expectRevert(InsufficientValue.selector);
        marketplace.acceptAsk{value: 1}(blacklisted, 1, 0);

        wrappedToken.deposit{value: minPrice * 2}();
        vm.expectEmit(true, true, true, false);
        emit IMarketplace.AcceptAsk(address(blacklisted), 1, minPrice * 2);
        marketplace.acceptAsk{value: minPrice * 2}(blacklisted, 1, 0);
    }
}
