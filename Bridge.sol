pragma solidity ^0.5.8;

import "./openzeppelin-contracts/token/ERC20/SafeERC20.sol";
import "./openzeppelin-contracts/token/ERC20/IERC20.sol";
import "./openzeppelin-contracts/ownership/Ownable.sol";
import "./openzeppelin-contracts/utils/Address.sol";
import "./openzeppelin-contracts/math/SafeMath.sol";
import "./AllowTokens.sol";
import "./ISideToken.sol";
import "./Utils.sol";

contract Bridge is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;
    
    
    address constant private NULL_ADDRESS = address(0);

    uint256 public trxBasedCost;
    uint256 public brgBasedCost;
    address public priceBot;
    address public BRGAddress;
    uint256 public lastDay;
    uint256 public spentToday;
    bool public isUpgrading;

    event Upgrading(bool isUpgrading);

    mapping (address => address) public originalTokens;
    mapping (address => bool) public knownTokens;
    AllowTokens public allowTokens;

    modifier whenNotUpgrading() {
        require(!isUpgrading);
        _;
    }

    function setTRXBasedPrice(uint256 price) public onlyPriceBot {
        trxBasedCost = price;
    }

    function setBRGBasedPrice(uint256 price) public onlyPriceBot {
        brgBasedCost = price;
    }

    function setBRGAddress(address _BRGAddress) public {
        BRGAddress = _BRGAddress;
    }

    modifier onlyPriceBot() {
        require(msg.sender == priceBot);
        _;
    }

    modifier onlyBRG() {
        require(msg.sender == BRGAddress);
        _;
    }

    function transferRequestWithTRX(address tokenToUse, uint256 amount, address to) external payable whenNotUpgrading {
        uint256 fee = msg.value;
        require(fee >= trxBasedCost);
        address payable _owner = address(owner()).toPayable();
        _owner.transfer(fee);
        crossTokens(tokenToUse, amount, to, true);
    }

    function onTokenTransfer(address from, uint256 amount, bytes memory data) public onlyBRG whenNotUpgrading {
        uint256 fee = amount;
        require(fee >= brgBasedCost);
        IERC20(BRGAddress).safeTransfer(owner(), fee);
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = address(this).delegatecall(data);
        require(success);
    }

    function receiveToken(address tokenToUse, uint256 amount, address to) external onlyBRG returns(bool){
        require(to != address(0));
        IERC20(tokenToUse).safeTransferFrom(msg.sender, address(this), amount);
        crossTokens(tokenToUse, amount, to, false);
    }

    function crossTokens(address tokenToUse, uint256 amount, address to, bool trxPayment) private {
        if(trxPayment) {
            IERC20(tokenToUse).safeTransferFrom(msg.sender, address(this), amount);
        }
        bool isASideToken = originalTokens[tokenToUse] != NULL_ADDRESS;
        if (isASideToken) {
            verifyWithAllowTokens(tokenToUse, amount, isASideToken);
            ISideToken(tokenToUse).burn(amount);
        } else {
            knownTokens[tokenToUse] = true;
            (uint8 decimals, uint256 granularity, string memory symbol) = Utils.getTokenInfo(tokenToUse);
            uint formattedAmount = amount;
            if(decimals != 18) {
                formattedAmount = amount.mul(uint256(10)**(18-decimals));
            }
            verifyWithAllowTokens(tokenToUse, formattedAmount, isASideToken);
        }
    }

    function verifyWithAllowTokens(address tokenToUse, uint256 amount, bool isASideToken) private {
        if (now > lastDay + 24 hours) {
            lastDay = now;
            spentToday = 0;
        }
        require(allowTokens.isValidTokenTransfer(tokenToUse, amount, spentToday, isASideToken));
        spentToday = spentToday.add(amount);
    }

    function startUpgrade() external onlyOwner {
        isUpgrading = true;
        emit Upgrading(isUpgrading);
    }

    function endUpgrade() external onlyOwner {
        isUpgrading = false;
        emit Upgrading(isUpgrading);
    }
}