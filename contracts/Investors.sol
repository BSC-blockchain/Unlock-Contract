pragma solidity ^0.5.0;

/*****************************************************************************
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 */
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");

        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;

        return c;
    }
}


/*****************************************************************************
 * @dev Interface of the KRC20 standard as defined in the EIP.
 */
interface ERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    function getMsgSender() external view returns (address);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through `transferFrom`. This is
     * zero by default.
     *
     * This value changes when `approve` or `transferFrom` are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     * Emits an `Approval` event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to `approve`. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}


/*****************************************************************************
 * @title TokenTimelock
 * @dev TokenTimelock is a token holder contract that will allow a
 * beneficiary to extract the tokens after a given release time.
 */
contract TokenTimelock is Ownable {
    using SafeMath for uint256;

    enum TypeOfRound { 
        SEED, 
        PRIVATE, 
        PUBLIC, 
        TEAM, 
        ADVISOR, 
        COMMUNITY, 
        ECOSYSTEM 
    }

    uint256 constant public AMOUNT_PER_RELEASE_1 = 200000 *10**18;
    uint256 constant public AMOUNT_PER_RELEASE_2 = 400000 *10**18;
    uint256 constant public AMOUNT_SEED_ROUND = 840000000 *10**18;
    uint256 constant public AMOUNT_PRIVATE_ROUND = 2730000000 *10**18;
    uint256 constant public AMOUNT_PUBLIC_ROUND = 210000000 *10**18;
    uint256 constant public AMOUNT_TEAM_ROUND = 3780000000 *10**18;
    uint256 constant public AMOUNT_ADVISOR_ROUND = 1680000000 *10**18;
    uint256 constant public AMOUNT_COMMUNITY_ROUND = 4410000000 *10**18;
    uint256 constant public AMOUNT_ECOSYSTEM_ROUND = 7350000000 *10**18;

    uint256 constant public PERIOD = 2592000; // 30 days
    uint256 constant public PERIOD_FIRST_RELEASE = 5184000; // 30 days
    uint256 constant public START_TIME = 1631707200; // 12:00:00 GMT 15/9/2021
    address public MEWA_TOKEN = 0x4A6ab76A232eFe1E1359420afe86F1eBf21bD103;

    uint256 public lockToken = 10000 * 10**18;
    uint256 public nextRelease;
    uint256 public countRelease;
    address public beneficiary = 0x641edb57C4bE2fAF1b12d18DE62dB8b08F8251e2;

    constructor() public {
        nextRelease = START_TIME + PERIOD.mul(countRelease);
    }
    
    /**
    * @dev Throws if called by any account other than the beneficiaries.
    */
    modifier onlyBeneficiary() {
        require(isBeneficiary(), "Ownable: caller is not the beneficiary");
        _;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @notice Transfers tokens held by timelock to beneficiary.
     */
    function release() public onlyBeneficiary {
        require(block.timestamp >= START_TIME + PERIOD.mul(countRelease), "TokenTimelock: current time is before release time");
        
        if (countRelease < 12) {
            uint256 cliff = block.timestamp.sub(nextRelease).div(PERIOD) + 1;
            uint256 amount = AMOUNT_PER_RELEASE_1.mul(cliff);
            if (amount >= lockToken) {
                ERC20(MEWA_TOKEN).transfer(beneficiary, lockToken);
                lockToken = 0;
            } else {
                nextRelease = nextRelease + PERIOD.mul(cliff);
                lockToken = lockToken.sub(amount);
                ERC20(MEWA_TOKEN).transfer(beneficiary, amount); 
            }
            
            countRelease += cliff;

        } else {
            require(ERC20(MEWA_TOKEN).balanceOf(address(this)).sub(AMOUNT_PER_RELEASE_2) >= 0, "TokenTimelock: no tokens to release");

            uint256 cliff = block.timestamp.sub(nextRelease).div(PERIOD) + 1;
            uint256 amount = AMOUNT_PER_RELEASE_2.mul(cliff);
            if (amount >= lockToken) {
                ERC20(MEWA_TOKEN).transfer(beneficiary, lockToken);
                lockToken = 0;
            } else {
                nextRelease = nextRelease + PERIOD.mul(cliff);
                lockToken = lockToken.sub(amount);
                ERC20(MEWA_TOKEN).transfer(beneficiary, amount); 
            }
            
            countRelease += cliff;
        }
        uint256 cliff = block.timestamp.sub(nextRelease).div(PERIOD) + 1;
        countRelease += cliff;
    }
    
    function getCurrentTime() public view returns(uint256) {
        return block.timestamp;
    }
    
    function getTimeReleaseNext() public view returns(uint256) {
        return START_TIME + PERIOD.mul(countRelease);
    }
    
    function setBeneficiary(address _addr) external onlyOwner {
        beneficiary = _addr;
    }

    function getBeneficiary() public view returns (address) {
        return beneficiary;
    }
    
    function getBalance() public view returns (uint256) {
        return ERC20(MEWA_TOKEN).balanceOf(msg.sender);
    }

    function isBeneficiary() public view returns (bool) {
        return msg.sender == beneficiary;
    }

    function transferFrom (address sender, address recipient, uint256 amount) external returns (bool) {
        return ERC20(MEWA_TOKEN).transferFrom(sender, recipient, amount);
    }

    function getTotalSupply() public view returns (uint256) {
        return ERC20(MEWA_TOKEN).totalSupply();
    }

    function getBalanceFromAddress(address from) public view returns (uint256) {
        return ERC20(MEWA_TOKEN).balanceOf(from);
    }

    function getAddress() public view returns (address){
        return msg.sender;
    }

    function getBalanceOfThisAddress() public view returns (uint256) {
        return ERC20(MEWA_TOKEN).balanceOf(address(this));
    }

    function approve (address spender, uint256 amount) external returns (bool) {
        return ERC20(MEWA_TOKEN).approve(spender, amount);
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return ERC20(MEWA_TOKEN).allowance(owner, spender);
    }

    function isValidType(TypeOfRound typeOfRound) public view returns (string memory) {
        if (TypeOfRound.SEED == typeOfRound) return "SEED";
        if (TypeOfRound.PRIVATE == typeOfRound) return "PRIVATE";
        return "";
    }
}