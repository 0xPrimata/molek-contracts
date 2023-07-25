// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "forge-std/Test.sol";
import "../src/MolekMarket.sol";
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

contract MarketTest is Test, IMarketplace, IERC721Receiver {
    TransparentUpgradeableProxy public market;
    MolekMarket public marketplaceImplementation;
    ProxyAdmin public proxyAdmin;
    TransferManager public transferManager;
    WrappedToken public wrappedToken;
    MolekMarket public marketplace;
    MockERC721 public blacklisted;
    MockERC721 public notBlacklisted;

    uint256 public minPrice = 10001;
    address public feeCollector;
    address public malicious = address(0x1337);

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function setUp() public {
        marketplaceImplementation = new MolekMarket();
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
        marketplace = MolekMarket(address(market));
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

    function createAsk(address token, uint256 tokenId, uint256 price) public {
        IERC721[] memory tokens = new IERC721[](1);
        tokens[0] = IERC721(token);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        uint256[] memory prices = new uint256[](1);
        prices[0] = price;
        marketplace.createAsk(tokens, tokenIds, prices);
    }

    function cancelAsk(address token, uint256 tokenId) public {
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
        marketplace.toggleBlacklist(address(blacklisted));

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

        (address seller, uint256 price) = marketplace.asks(
            address(blacklisted),
            1
        );
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
        (address seller1, uint256 price1) = marketplace.asks(
            address(blacklisted),
            1
        );
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
        (address seller, uint256 price) = marketplace.asks(
            address(blacklisted),
            1
        );
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

    function testCreateCancelAskFuzz(uint8 tokenId, uint256 price) public {
        testBlacklisted();
        vm.assume(tokenId < 3);
        vm.assume(price >= minPrice);

        createAsk(address(blacklisted), tokenId, price);
        (address seller, uint256 storedPrice) = marketplace.asks(
            address(blacklisted),
            tokenId
        );
        assertEq(seller, address(this));
        assertEq(storedPrice, price);

        cancelAsk(address(blacklisted), tokenId);
        (address seller2, uint256 storedPrice2) = marketplace.asks(
            address(blacklisted),
            tokenId
        );

        assertEq(seller2, address(0x0));
        assertEq(storedPrice2, 0);
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

        wrappedToken.approve(address(marketplace), minPrice * 2);
        uint256 snapshot = vm.snapshot();
        wrappedToken.deposit{value: minPrice * 2}();
        vm.expectEmit(true, true, true, false);
        emit IMarketplace.AcceptAsk(address(blacklisted), 1, minPrice * 2);
        marketplace.acceptAsk(blacklisted, 1, minPrice * 2);

        vm.revertTo(snapshot);
        uint256 snapshot2 = vm.snapshot();
        // test mixed amounts
        address seller = address(this);
        uint256 balance = wrappedToken.balanceOf(seller);
        uint256 initialAvaxBalance = seller.balance;
        uint256 avaxBalance = address(malicious).balance;
        console.log(balance);
        console.log(avaxBalance);
        vm.deal(malicious, minPrice * 2);
        vm.startPrank(malicious);
        wrappedToken.deposit{value: minPrice}();
        wrappedToken.approve(address(marketplace), minPrice);
        vm.expectEmit(true, true, true, false);
        emit IMarketplace.AcceptAsk(address(blacklisted), 1, minPrice * 2);
        marketplace.acceptAsk{value: minPrice}(blacklisted, 1, minPrice);
        assertTrue(wrappedToken.balanceOf(seller) == balance + (minPrice * 2));
        assertTrue(wrappedToken.balanceOf(malicious) == 0);
        assertTrue(address(this).balance == initialAvaxBalance);
        assertTrue(address(malicious).balance == avaxBalance);
        vm.stopPrank();

        vm.revertTo(snapshot2);
        vm.deal(malicious, minPrice * 2 + 1);
        vm.startPrank(malicious);
        wrappedToken.deposit{value: minPrice}();
        wrappedToken.approve(address(marketplace), minPrice);
        vm.expectEmit(true, true, true, false);
        emit IMarketplace.AcceptAsk(address(blacklisted), 1, minPrice * 2);
        marketplace.acceptAsk{value: minPrice + 1}(blacklisted, 1, minPrice);
        assertTrue(wrappedToken.balanceOf(seller) == balance + (minPrice * 2));
        assertTrue(wrappedToken.balanceOf(malicious) == 1);
        assertTrue(address(this).balance == initialAvaxBalance);
        assertTrue(address(malicious).balance == avaxBalance);
        vm.stopPrank();
    }

    function testCreateAcceptAskFuzz(
        address buyer,
        uint256 tokenId,
        uint256 price,
        uint256 amountInAvax,
        uint256 excess,
        uint256 excessWavax
    ) public {
        testBlacklisted();
        price = bound(price, minPrice, type(uint128).max);
        amountInAvax = bound(amountInAvax, 0, type(uint128).max);
        excess = bound(excess, 0, type(uint64).max);
        excessWavax = bound(excessWavax, 0, type(uint64).max);
        tokenId = bound(tokenId, 0, 2);
        vm.assume(amountInAvax < price);

        vm.assume(buyer != address(0));

        blacklisted.approve(address(marketplace), tokenId);
        createAsk(address(blacklisted), tokenId, price);
        (address seller, uint256 storedPrice) = marketplace.asks(
            address(blacklisted),
            tokenId
        );
        assertEq(seller, address(this));
        assertEq(storedPrice, price);

        vm.deal(buyer, price + excess + excessWavax);
        vm.startPrank(buyer);
        wrappedToken.deposit{value: price - amountInAvax + excessWavax}();
        wrappedToken.approve(
            address(marketplace),
            price - amountInAvax + excessWavax
        );
        marketplace.acceptAsk{value: amountInAvax + excess}(
            blacklisted,
            tokenId,
            price + excessWavax - amountInAvax
        );
        (address seller2, uint256 storedPrice2) = marketplace.asks(
            address(blacklisted),
            tokenId
        );

        vm.stopPrank();

        assertEq(wrappedToken.balanceOf(seller), price);
        assertEq(wrappedToken.balanceOf(buyer), excess + excessWavax);

        assertEq(seller2, address(0x0));
        assertEq(storedPrice2, 0);
    }

    function testCreateAcceptAskAVAXFuzz(
        address buyer,
        uint256 tokenId,
        uint256 price,
        uint256 excess
    ) public {
        testBlacklisted();
        price = bound(price, minPrice, type(uint128).max);
        excess = bound(excess, 0, type(uint64).max);
        tokenId = bound(tokenId, 0, 2);

        vm.assume(buyer != address(0));

        blacklisted.approve(address(marketplace), tokenId);
        createAsk(address(blacklisted), tokenId, price);
        (address seller, uint256 storedPrice) = marketplace.asks(
            address(blacklisted),
            tokenId
        );
        assertEq(seller, address(this));
        assertEq(storedPrice, price);

        vm.deal(buyer, price + excess);
        vm.startPrank(buyer);
        marketplace.acceptAskAVAX{value: price + excess}(blacklisted, tokenId);
        (address seller2, uint256 storedPrice2) = marketplace.asks(
            address(blacklisted),
            tokenId
        );

        vm.stopPrank();

        assertEq(wrappedToken.balanceOf(seller), price);
        assertEq(wrappedToken.balanceOf(buyer), excess);

        assertEq(seller2, address(0x0));
        assertEq(storedPrice2, 0);
    }
}
