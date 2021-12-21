pragma solidity ^0.5.8;

import "./openzeppelin-contracts/token/ERC777/ERC777.sol";
import "./ISideToken.sol";

contract SideToken is ISideToken, ERC777 {

    address public minter;
    address public burner;
    uint256 private _granularity;

    constructor(string memory _tokenName, string memory _tokenSymbol, address _minterAddr, address _burnerAddr, uint256 _newGranularity) ERC777(_tokenName, _tokenSymbol, new address[](0)) public {
        require(_minterAddr != address(0) && _burnerAddr != address(0));
        minter = _minterAddr;
        burner = _burnerAddr;
        _granularity = _newGranularity;
    }

    modifier onlyMinter() {
        require(_msgSender() == minter);
        _;
    }

    modifier onlyBurner() {
        require(_msgSender() == burner);
        _;
    }
    
    function mint(
        address account,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    )
    external onlyMinter
    {
        _mint(_msgSender(), account, amount, userData, operatorData);
    }

    function burn(uint256 amount) external onlyBurner {
        _burn(amount);
    }

    function granularity() public view returns (uint256) {
        return _granularity;
    }
}