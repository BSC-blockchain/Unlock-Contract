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

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
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

    string[7] private TYPE_OF_ROUND = ["SEED", "PRIVATE", "PUBLIC", "TEAM", "ADVISOR", "COMMUNITY", "ECOSYSTEM"];

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
    address[] public beneficiaryList;

    mapping (string => address[]) private roundAddress;
    mapping (address => uint256) private beneficiaryAllowances;
    mapping (address => uint256) private beneficiaryClaim;

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
    function release() public onlyOwner {
        require(block.timestamp >= START_TIME + PERIOD.mul(countRelease), "TokenTimelock: current time is before release time");
        uint256 cliff = block.timestamp.sub(nextRelease).div(PERIOD) + 1;
        addAmount();
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

    function isBeneficiary() public view returns (bool) {
        return msg.sender == beneficiary;
    }

    function getBalanceFromAddress(address from) public view returns (uint256) {
        return ERC20(MEWA_TOKEN).balanceOf(from);
    }

    function getBalanceOfThisAddress() public view returns (uint256) {
        return ERC20(MEWA_TOKEN).balanceOf(address(this));
    }

    function isValidType(string memory typeOfRound) public view returns (bool) {
        bool isValid = false;
    
        for (uint i=0; i < TYPE_OF_ROUND.length; i++) {
            if (keccak256(abi.encodePacked(typeOfRound)) == keccak256(abi.encodePacked(TYPE_OF_ROUND[i]))) {
                isValid = true;
            }
        }
        return isValid;
    }

    function addAddressToRound(address _beneficiary, uint256 amount, string memory round) public onlyOwner {
        require(isValidType(round), "Unlock: Round not found");
        roundAddress[round].push(_beneficiary);
        beneficiaryAllowances[_beneficiary] = amount;
    }

    function getListAddressByRound(string memory round) public view returns (address[] memory) {
        require(isValidType(round), "Unlock: Round not found");
        return roundAddress[round];
    }

    function getBeneficiaryAllowances(address _beneficiary) public view returns (uint256) {
        return beneficiaryAllowances[_beneficiary];
    }

    function getBeneficiaryClaims(address _beneficiary) public view returns (uint256) {
        return beneficiaryClaim[_beneficiary];
    }

    function getPercentSeedPrivateRound() private view returns (uint256) {
        if (countRelease == 0)
            return 8;

        if (countRelease == 2) 
            return 2;
        
        if(countRelease > 2 && countRelease <= 12)
            return 9;

        return 0;
    }

    function getPercentPublicRound() private view returns (uint256) {
        if (countRelease == 0)
            return 50;

        if (countRelease > 1 && countRelease < 4)
            return 25;

        return 0;
    }

    function getPercentTeamRound() private view returns (uint256) {
        if (countRelease > 0 && countRelease < 40)
            return 25;

        return 0;
    }

    function getPercentAdvisorRound() private view returns (uint256) {
        if (countRelease == 0) {
            return 10;
        }
        if (countRelease > 0 && countRelease.mod(3) == 0 && countRelease < 31)
            return 3;

        return 0;
    }

    function getPercentCommunityRound() private view returns (uint256) {
        if (countRelease == 0)
            return uint256(35)/uint256(2);

        if (countRelease > 0 && countRelease < 25)
            return uint256(33)/uint256(10);

        return 0;
    }

    function getPercentEcosystemRound() private view returns (uint256) {
        if (countRelease > 0 && countRelease < 25)
            return 2;

        return 0;
    }

    function addAmount() private {
        for (uint i=0; i < TYPE_OF_ROUND.length; i++) {
            bytes32 roundByte = keccak256(abi.encodePacked(TYPE_OF_ROUND[i]));
            uint256 percent = 0;
            if(keccak256(abi.encodePacked("SEED")) == roundByte) {
                percent = getPercentSeedPrivateRound();
            } else if (keccak256(abi.encodePacked("PRIVATE")) == roundByte){
                percent = getPercentSeedPrivateRound();
            } else if (keccak256(abi.encodePacked("PUBLIC")) == roundByte){
                percent = getPercentPublicRound();
            } else if (keccak256(abi.encodePacked("TEAM")) == roundByte){
                percent = getPercentTeamRound();
            } else if (keccak256(abi.encodePacked("ADVISOR")) == roundByte){
                percent = getPercentAdvisorRound();
            } else if (keccak256(abi.encodePacked("PUBLIC")) == roundByte){
                percent = getPercentPublicRound();
            } else if (keccak256(abi.encodePacked("ECOSYSTEM")) == roundByte){
                percent = getPercentEcosystemRound();
            }
            for (uint j=0; j < roundAddress[TYPE_OF_ROUND[i]].length; j++) {
                address _beneficiary = roundAddress[TYPE_OF_ROUND[i]][j];
                beneficiaryClaim[_beneficiary] = beneficiaryAllowances[_beneficiary].mul(percent).div(100);
            }
        }
    }
}