// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { LibCommon } from "./lib/LibCommon.sol";

/// @title A Defi Token implementation with extended functionalities
/// @notice Implements ERC20 standards with additional features like tax and deflation
contract DefiToken is ERC20, Ownable {
  // Constants
  uint256 private constant MAX_BPS_AMOUNT = 10_000;
  uint256 private constant MAX_ALLOWED_BPS = 5_000;
  string public constant VERSION = "defi_v_1";

  // State Variables
  string public initialDocumentUri;
  string public documentUri;
  uint256 public immutable initialSupply;
  uint256 public immutable initialMaxTokenAmountPerAddress;
  uint256 public maxTokenAmountPerAddress;

  /// @notice Configuration properties for the ERC20 token
  struct ERC20ConfigProps {
    bool _isMintable;
    bool _isBurnable;
    bool _isDocumentAllowed;
    bool _isMaxAmountOfTokensSet;
    bool _isTaxable;
    bool _isDeflationary;
  }
  ERC20ConfigProps private configProps;

  address public immutable initialTokenOwner;
  uint8 private immutable _decimals;
  address public taxAddress;
  uint256 public taxBPS;
  uint256 public deflationBPS;

  // Events
  event DocumentUriSet(string newDocUri);
  event MaxTokenAmountPerSet(uint256 newMaxTokenAmount);
  event TaxConfigSet(address indexed _taxAddress, uint256 indexed _taxBPS);
  event DeflationConfigSet(uint256 indexed _deflationBPS);

  // Custom Errors
  error InvalidMaxTokenAmount(uint256 maxTokenAmount);
  error InvalidDecimals(uint8 decimals);
  error MaxTokenAmountPerAddrLtPrevious();
  error DestBalanceExceedsMaxAllowed(address addr);
  error MintingNotEnabled();
  error BurningNotEnabled();
  error DocumentUriNotAllowed();
  error MaxTokenAmountNotAllowed();
  error TokenIsNotTaxable();
  error TokenIsNotDeflationary();
  error InvalidTaxBPS(uint256 bps);
  error InvalidDeflationBPS(uint256 bps);

  /// @notice Constructor to initialize the DeFi token
  /// @param name_ Name of the token
  /// @param symbol_ Symbol of the token
  /// @param initialSupplyToSet Initial supply of tokens
  /// @param decimalsToSet Number of decimals for the token
  /// @param tokenOwner Address of the initial token owner
  /// @param customConfigProps Configuration properties for the token
  /// @param maxTokenAmount Maximum token amount per address
  /// @param newDocumentUri URI for the document associated with the token
  /// @param _taxAddress Address where tax will be sent
  /// @param _taxBPS Basis points for tax calculation
  /// @param _deflationBPS Basis points for deflation calculation
  constructor(
    string memory name_,
    string memory symbol_,
    uint256 initialSupplyToSet,
    uint8 decimalsToSet,
    address tokenOwner,
    ERC20ConfigProps memory customConfigProps,
    uint256 maxTokenAmount,
    string memory newDocumentUri,
    address _taxAddress,
    uint256 _taxBPS,
    uint256 _deflationBPS
  ) ERC20(name_, symbol_) {
    if (customConfigProps._isMaxAmountOfTokensSet) {
      if (maxTokenAmount == 0) {
        revert InvalidMaxTokenAmount(maxTokenAmount);
      }
    }
    if (decimalsToSet > 18) {
      revert InvalidDecimals(decimalsToSet);
    }
    if (customConfigProps._isTaxable) {
      if (_taxBPS > MAX_ALLOWED_BPS) {
        revert InvalidTaxBPS(_taxBPS);
      }
      LibCommon.validateAddress(_taxAddress);
      taxAddress = _taxAddress;
      taxBPS = _taxBPS;
    }
    if (customConfigProps._isDeflationary) {
      if (_deflationBPS > MAX_ALLOWED_BPS) {
        revert InvalidDeflationBPS(_deflationBPS);
      }
      deflationBPS = _deflationBPS;
    }
    LibCommon.validateAddress(tokenOwner);

    initialSupply = initialSupplyToSet;
    initialMaxTokenAmountPerAddress = maxTokenAmount;
    initialDocumentUri = newDocumentUri;
    initialTokenOwner = tokenOwner;
    _decimals = decimalsToSet;
    configProps = customConfigProps;
    documentUri = newDocumentUri;
    maxTokenAmountPerAddress = maxTokenAmount;

    if (initialSupplyToSet != 0) {
      _mint(tokenOwner, initialSupplyToSet * 10 ** decimalsToSet);
    }

    if (tokenOwner != msg.sender) {
      transferOwnership(tokenOwner);
    }
  }

  // Public and External Functions

  /// @notice Checks if the token is mintable
  /// @return True if the token can be minted
  function isMintable() public view returns (bool) {
    return configProps._isMintable;
  }

  /// @notice Checks if the token is burnable
  /// @return True if the token can be burned
  function isBurnable() public view returns (bool) {
    return configProps._isBurnable;
  }

  /// @notice Checks if the maximum amount of tokens per address is set
  /// @return True if there is a maximum limit for token amount per address
  function isMaxAmountOfTokensSet() public view returns (bool) {
    return configProps._isMaxAmountOfTokensSet;
  }

  /// @notice Checks if setting a document URI is allowed
  /// @return True if setting a document URI is allowed
  function isDocumentUriAllowed() public view returns (bool) {
    return configProps._isDocumentAllowed;
  }

  /// @notice Returns the number of decimals used for the token
  /// @return The number of decimals
  function decimals() public view virtual override returns (uint8) {
    return _decimals;
  }

  /// @notice Checks if the token is taxable
  /// @return True if the token has tax applied on transfers
  function isTaxable() public view returns (bool) {
    return configProps._isTaxable;
  }

  /// @notice Checks if the token is deflationary
  /// @return True if the token has deflation applied on transfers
  function isDeflationary() public view returns (bool) {
    return configProps._isDeflationary;
  }

  /// @notice Sets a new document URI
  /// @dev Can only be called by the contract owner
  /// @param newDocumentUri The new URI to be set
  function setDocumentUri(string memory newDocumentUri) external onlyOwner {
    if (!isDocumentUriAllowed()) {
      revert DocumentUriNotAllowed();
    }
    documentUri = newDocumentUri;
    emit DocumentUriSet(newDocumentUri);
  }

  /// @notice Sets a new maximum token amount per address
  /// @dev Can only be called by the contract owner
  /// @param newMaxTokenAmount The new maximum token amount per address
  function setMaxTokenAmountPerAddress(
    uint256 newMaxTokenAmount
  ) external onlyOwner {
    if (!isMaxAmountOfTokensSet()) {
      revert MaxTokenAmountNotAllowed();
    }
    if (newMaxTokenAmount <= maxTokenAmountPerAddress) {
      revert MaxTokenAmountPerAddrLtPrevious();
    }

    maxTokenAmountPerAddress = newMaxTokenAmount;
    emit MaxTokenAmountPerSet(newMaxTokenAmount);
  }

  /// @notice Sets a new tax configuration
  /// @dev Can only be called by the contract owner
  /// @param _taxAddress The address where tax will be sent
  /// @param _taxBPS The tax rate in basis points
  function setTaxConfig(
    address _taxAddress,
    uint256 _taxBPS
  ) external onlyOwner {
    if (!isTaxable()) {
      revert TokenIsNotTaxable();
    }
    if (_taxBPS > MAX_ALLOWED_BPS) {
      revert InvalidTaxBPS(_taxBPS);
    }
    LibCommon.validateAddress(_taxAddress);
    taxAddress = _taxAddress;
    taxBPS = _taxBPS;
    emit TaxConfigSet(_taxAddress, _taxBPS);
  }

  /// @notice Sets a new deflation configuration
  /// @dev Can only be called by the contract owner
  /// @param _deflationBPS The deflation rate in basis points
  function setDeflationConfig(uint256 _deflationBPS) external onlyOwner {
    if (!isDeflationary()) {
      revert TokenIsNotDeflationary();
    }
    if (_deflationBPS > MAX_ALLOWED_BPS) {
      revert InvalidDeflationBPS(_deflationBPS);
    }
    deflationBPS = _deflationBPS;
    emit DeflationConfigSet(_deflationBPS);
  }

  /// @notice Transfers tokens to a specified address
  /// @dev Overrides the ERC20 transfer function with added tax and deflation logic
  /// @param to The address to transfer tokens to
  /// @param amount The amount of tokens to be transferred
  /// @return True if the transfer was successful
  function transfer(
    address to,
    uint256 amount
  ) public virtual override returns (bool) {
    uint256 taxAmount = _taxAmount(msg.sender, amount);
    uint256 deflationAmount = _deflationAmount(amount);
    uint256 amountToTransfer = amount - taxAmount - deflationAmount;

    if (isMaxAmountOfTokensSet()) {
      if (balanceOf(to) + amountToTransfer > maxTokenAmountPerAddress) {
        revert DestBalanceExceedsMaxAllowed(to);
      }
    }

    if (taxAmount != 0) {
      _transfer(msg.sender, taxAddress, taxAmount);
    }
    if (deflationAmount != 0) {
      _burn(msg.sender, deflationAmount);
    }
    return super.transfer(to, amountToTransfer);
  }

  /// @notice Transfers tokens from one address to another
  /// @dev Overrides the ERC20 transferFrom function with added tax and deflation logic
  /// @param from The address which you want to send tokens from
  /// @param to The address which you want to transfer to
  /// @param amount The amount of tokens to be transferred
  /// @return True if the transfer was successful
  function transferFrom(
    address from,
    address to,
    uint256 amount
  ) public virtual override returns (bool) {
    uint256 taxAmount = _taxAmount(from, amount);
    uint256 deflationAmount = _deflationAmount(amount);
    uint256 amountToTransfer = amount - taxAmount - deflationAmount;

    if (isMaxAmountOfTokensSet()) {
      if (balanceOf(to) + amountToTransfer > maxTokenAmountPerAddress) {
        revert DestBalanceExceedsMaxAllowed(to);
      }
    }

    if (taxAmount != 0) {
      _transfer(from, taxAddress, taxAmount);
    }
    if (deflationAmount != 0) {
      _burn(from, deflationAmount);
    }

    return super.transferFrom(from, to, amountToTransfer);
  }

  /// @notice Mints new tokens to a specified address
  /// @dev Can only be called by the contract owner and if minting is enabled
  /// @param to The address to mint tokens to
  /// @param amount The amount of tokens to mint
  function mint(address to, uint256 amount) external onlyOwner {
    if (!isMintable()) {
      revert MintingNotEnabled();
    }
    if (isMaxAmountOfTokensSet()) {
      if (balanceOf(to) + amount > maxTokenAmountPerAddress) {
        revert DestBalanceExceedsMaxAllowed(to);
      }
    }

    super._mint(to, amount);
  }

  /// @notice Burns a specific amount of tokens
  /// @dev Can only be called by the contract owner and if burning is enabled
  /// @param amount The amount of tokens to be burned
  function burn(uint256 amount) external onlyOwner {
    if (!isBurnable()) {
      revert BurningNotEnabled();
    }
    _burn(msg.sender, amount);
  }

  /// @notice Renounces ownership of the contract
  /// @dev Leaves the contract without an owner, disabling any functions that require the owner's authorization
  function renounceOwnership() public override onlyOwner {
    super.renounceOwnership();
  }

  /// @notice Transfers ownership of the contract to a new account
  /// @dev Can only be called by the current owner
  /// @param newOwner The address of the new owner
  function transferOwnership(address newOwner) public override onlyOwner {
    super.transferOwnership(newOwner);
  }

  // Internal Functions

  /// @notice Calculates the tax amount for a transfer
  /// @param sender The address initiating the transfer
  /// @param amount The amount of tokens being transferred
  /// @return taxAmount The calculated tax amount
  function _taxAmount(
    address sender,
    uint256 amount
  ) internal view returns (uint256 taxAmount) {
    taxAmount = 0;
    if (taxBPS != 0 && sender != taxAddress) {
      taxAmount = (amount * taxBPS) / MAX_BPS_AMOUNT;
    }
  }

  /// @notice Calculates the deflation amount for a transfer
  /// @param amount The amount of tokens being transferred
  /// @return deflationAmount The calculated deflation amount
  function _deflationAmount(
    uint256 amount
  ) internal view returns (uint256 deflationAmount) {
    deflationAmount = 0;
    if (deflationBPS != 0) {
      deflationAmount = (amount * deflationBPS) / MAX_BPS_AMOUNT;
    }
  }
}