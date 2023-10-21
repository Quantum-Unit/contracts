// 
//  ██████╗ ██╗   ██╗ █████╗ ███╗   ██╗████████╗██╗   ██╗███╗   ███╗    ██╗   ██╗███╗   ██╗██╗████████╗
// ██╔═══██╗██║   ██║██╔══██╗████╗  ██║╚══██╔══╝██║   ██║████╗ ████║    ██║   ██║████╗  ██║██║╚══██╔══╝
// ██║   ██║██║   ██║███████║██╔██╗ ██║   ██║   ██║   ██║██╔████╔██║    ██║   ██║██╔██╗ ██║██║   ██║   
// ██║▄▄ ██║██║   ██║██╔══██║██║╚██╗██║   ██║   ██║   ██║██║╚██╔╝██║    ██║   ██║██║╚██╗██║██║   ██║   
// ╚██████╔╝╚██████╔╝██║  ██║██║ ╚████║   ██║   ╚██████╔╝██║ ╚═╝ ██║    ╚██████╔╝██║ ╚████║██║   ██║   
//  ╚══▀▀═╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚═╝     ╚═╝     ╚═════╝ ╚═╝  ╚═══╝╚═╝   ╚═╝   
//                                                                                                    
// Quantum Unit is an investment platform that can earn a 1% daily return on your investment. 
// You don't need to lock your funds, and you can withdraw them at any time.
// https://qu.finance/
// 


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "./ABDKMath64x64.sol";
import "./TokenInterface.sol";
import "@openzeppelin/contracts-upgradeable@4.9.3/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable@4.9.3/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable@4.9.3/proxy/utils/UUPSUpgradeable.sol";

contract QuantumUnit is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _tokenAddress) initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();
        protocolFeePercent = 50000000000000000;
        refererFeePercent = 50000000000000000;
        withdrawFee = 100000000000000000;
        minInvestSum = 10000000000000000;
        minWithdrawSum = 5000000000000000;
        tokenReward = 50000000000000000;
        interestPerBlock = 347222222200;
        blockEverySecond = 3;

        tokenAddress = _tokenAddress;
        tokenContract = IERC20(tokenAddress);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    uint256 public protocolFeePercent = 50000000000000000;
    uint256 public refererFeePercent = 50000000000000000;
    uint256 public withdrawFee = 100000000000000000;
    uint256 public minInvestSum = 10000000000000000;
    uint256 public minWithdrawSum = 5000000000000000;
    uint256 public tokenReward = 50000000000000000;
    uint256 public interestPerBlock = 347222222200;
    uint256 public blockEverySecond = 3;
    ///
    uint256 public totalReferralPaided;
    uint256 public totalWithdrawn;
    uint256 public totalUsers;
    uint256 public totalInvested;

    address public tokenAddress;
    IERC20 public tokenContract;

    mapping(address => uint256) private users;
    mapping(address => uint256) private lastInvest;

    event Invest(address sender, address referer, uint256 value);
    event Withdraw(address sender, uint256 sum);

    function invest(address referer) public payable {
        require(msg.value >= minInvestSum, "Your investment amount must be greater");
        users[msg.sender] = getBalance(msg.sender) + msg.value;
        totalInvested += msg.value;

        if (lastInvest[msg.sender] == 0) {
            totalUsers++;
        }

        lastInvest[msg.sender] = block.timestamp;
        uint256 protocolFee = msg.value * protocolFeePercent / 1 ether;
        uint256 refererFee = msg.value * refererFeePercent / 1 ether;

        (bool success1, ) = owner().call{value: protocolFee}("");
        (bool success2, ) = referer.call{value: refererFee}("");
        totalReferralPaided += refererFee;

        require(success1 && success2, "Unable to invest");
        emit Invest(msg.sender, referer, msg.value);
    }

    function withdraw(uint256 sum) public {
        uint256 balance = getBalance(msg.sender);
        require(balance >= sum, "You do not have enough funds to withdraw");
        require(sum >= minWithdrawSum, "Withdrawal amount below minimum");
        totalWithdrawn += sum;
        
        users[msg.sender] = balance - sum;
        lastInvest[msg.sender] = block.timestamp;
        uint256 withdrawSum = sum - sum * withdrawFee / 1 ether;
        (bool success1, ) = msg.sender.call{ value: withdrawSum }("");
        require(success1, "Unable to withdraw");
        
        tokenContract.mint(msg.sender, sum * tokenReward / 1 ether);
        emit Withdraw(msg.sender, sum);
    }

    function withdrawAll() public {
        withdraw(getBalance(msg.sender));
    }
    
    function getBalance(address adr) public view returns (uint256) {
        uint256 balance = users[adr];
        uint256 lastInvestTimestamp = lastInvest[adr];

        if (balance == 0) {
            return 0;
        }

        uint256 currentPeriod = (block.timestamp - lastInvestTimestamp) / blockEverySecond;
        return compounding(balance, interestPerBlock, currentPeriod);
    }

    function compounding(uint principal, uint ratio, uint n) public pure returns (uint) {
        return ABDKMath64x64.mulu (
            pow (
                ABDKMath64x64.add (
                    ABDKMath64x64.fromUInt (1), 
                    ABDKMath64x64.divu (
                    ratio,
                    10**18)),
            n),
        principal);
    }

    function setProtocolFeePercent(uint256 _feePercent) public onlyOwner {
        protocolFeePercent = _feePercent;
    }

    function setRefererFeePercent(uint256 _feePercent) public onlyOwner {
        refererFeePercent = _feePercent;
    }

    function setMinInvestSum(uint256 _sum) public onlyOwner {
        minInvestSum = _sum;
    }

    function setMinWithdrawSum(uint256 _sum) public onlyOwner {
        minWithdrawSum = _sum;
    }

    function setWithdrawFee(uint256 _feePercent) public onlyOwner {
        withdrawFee = _feePercent;
    }

    function setInterestPerBlock(uint256 _interest) public onlyOwner {
        interestPerBlock = _interest;
    }

    function setBlockEverySecond(uint256 _blocks) public onlyOwner {
        blockEverySecond = _blocks;
    }

    function setTokenAddress(address _address) public onlyOwner {
        tokenAddress = _address;
        tokenContract = IERC20(tokenAddress);
    }

    function setTokenReward(uint256 _tokenReward) public onlyOwner {
        tokenReward = _tokenReward;
    }

    function pow (int128 x, uint n) private pure returns (int128 r) {
        r = ABDKMath64x64.fromUInt (1);
        while (n > 0) {
            if (n % 2 == 1) {
                r = ABDKMath64x64.mul (r, x);
                n -= 1;
            } else {
                x = ABDKMath64x64.mul (x, x);
                n /= 2;
            }
        }
    }
}
