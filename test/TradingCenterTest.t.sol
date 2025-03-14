// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {console2} from "forge-std/Test.sol";
import "solmate/tokens/ERC20.sol";
import {TradingCenter, IERC20} from "../src/TradingCenter.sol";
import {TradingCenterV2} from "../src/TradingCenterV2.sol";
import {UpgradeableProxy} from "../src/UpgradeableProxy.sol";

contract FiatToken is ERC20 {
    constructor(string memory name, string memory symbol, uint8 decimals) ERC20(name, symbol, decimals) {}
}

contract TradingCenterTest is Test {
    // Owner and users
    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    // Contracts
    TradingCenter tradingCenter;
    TradingCenter proxyTradingCenter;
    UpgradeableProxy proxy;
    IERC20 usdt;
    IERC20 usdc;

    // Initial balances
    uint256 initialBalance = 100000 ether;
    uint256 userInitialBalance = 10000 ether;

    function setUp() public {
        vm.startPrank(owner);
        // 1. Owner deploys TradingCenter
        tradingCenter = new TradingCenter();
        // 2. Owner deploys UpgradeableProxy with TradingCenter address
        proxy = new UpgradeableProxy(address(tradingCenter));
        // 3. Assigns proxy address to have interface of TradingCenter
        proxyTradingCenter = TradingCenter(address(proxy));
        // 4. Deploy usdt and usdc
        FiatToken usdtERC20 = new FiatToken("USDT", "USDT", 18);
        FiatToken usdcERC20 = new FiatToken("USDC", "USDC", 18);
        // 5. Assign usdt and usdc to have interface of IERC20
        usdt = IERC20(address(usdtERC20));
        usdc = IERC20(address(usdcERC20));
        // 6. owner initialize on proxyTradingCenter
        proxyTradingCenter.initialize(usdt, usdc);
        vm.stopPrank();

        // Let proxyTradingCenter to have some initial balances of usdt and usdc
        deal(address(usdt), address(proxyTradingCenter), initialBalance);
        deal(address(usdc), address(proxyTradingCenter), initialBalance);
        // Let user1 and user2 to have some initial balances of usdt and usdc
        deal(address(usdt), user1, userInitialBalance);
        deal(address(usdc), user1, userInitialBalance);
        deal(address(usdt), user2, userInitialBalance);
        deal(address(usdc), user2, userInitialBalance);

        // user1 approve to proxyTradingCenter
        vm.startPrank(user1);
        usdt.approve(address(proxyTradingCenter), type(uint256).max);
        usdc.approve(address(proxyTradingCenter), type(uint256).max);
        vm.stopPrank();

        // user1 approve to proxyTradingCenter
        vm.startPrank(user2);
        usdt.approve(address(proxyTradingCenter), type(uint256).max);
        usdc.approve(address(proxyTradingCenter), type(uint256).max);
        vm.stopPrank();
    }

    function testUpgrade() public {
        assertEq(proxyTradingCenter.initialized(), true);
        assertEq(address(proxyTradingCenter.usdc()), address(usdc));
        assertEq(address(proxyTradingCenter.usdt()), address(usdt));
        assertEq(proxyTradingCenter.VERSION(), "0.0.1");

        // Let's pretend that you are proxy owner
        vm.startPrank(owner);
        // Try to upgrade the proxy to TradingCenterV2
        proxy.upgradeTo(address(new TradingCenterV2()));
        TradingCenterV2 proxyTradingCenterV2 = TradingCenterV2(address(proxy));
        vm.stopPrank();
        
        // And check if all state are correct (initialized, usdt address, usdc address)
        assertEq(address(proxyTradingCenterV2.usdc()), address(usdc));
        assertEq(address(proxyTradingCenterV2.usdt()), address(usdt));
        assertEq(proxyTradingCenterV2.VERSION(), "0.0.2");
    }

    function testGetLog() public {
        console2.logUint(usdt.allowance(user1, address(proxyTradingCenter)));
        console2.logUint(usdc.allowance(user1, address(proxyTradingCenter)));
        console2.logUint(usdt.balanceOf(user1));
    }

    function testRugPull() public {
        // Let's pretend that you are proxy owner
        vm.startPrank(owner);
        // Try to upgrade the proxy to TradingCenterV2
        proxy.upgradeTo(address(new TradingCenterV2()));
        TradingCenterV2 proxyTradingCenterV2 = TradingCenterV2(address(proxy));
        // And empty users' usdc and usdt
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;

        proxyTradingCenterV2.doRugPull(users);
        vm.stopPrank();

        // Assert users's balances are 0
        assertEq(usdt.balanceOf(user1), 0);
        assertEq(usdc.balanceOf(user1), 0);
        assertEq(usdt.balanceOf(user2), 0);
        assertEq(usdc.balanceOf(user2), 0);

        // Assert owner's balances are sum of users amount
        assertEq(usdt.balanceOf(owner), 20000 ether);
        assertEq(usdc.balanceOf(owner), 20000 ether);
    }
}
