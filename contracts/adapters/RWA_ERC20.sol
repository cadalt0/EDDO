// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRWAAdapter} from "../interfaces/IRWAAdapter.sol";
import {IRulesEngine} from "../interfaces/IRulesEngine.sol";
import {IContext} from "../interfaces/IContext.sol";
import {Context} from "../core/Context.sol";

/**
 * @title RWA_ERC20
 * @notice RWA-compliant ERC20 token with rules engine integration
 * @dev Full ERC20 implementation with pre/post hooks for rule evaluation
 */
contract RWA_ERC20 is IRWAAdapter {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    IRulesEngine private immutable _rulesEngine;
    address public immutable override asset;
    bool public override paused;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    address public admin;
    address public minter;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Paused(address indexed account);
    event Unpaused(address indexed account);

    modifier onlyAdmin() {
        require(msg.sender == admin, "RWA_ERC20: caller is not admin");
        _;
    }

    modifier onlyMinter() {
        require(msg.sender == minter, "RWA_ERC20: caller is not minter");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "RWA_ERC20: paused");
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address rulesEngine_
    ) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
        _rulesEngine = IRulesEngine(rulesEngine_);
        asset = address(this);
        admin = msg.sender;
        minter = msg.sender;
    }

    /// @inheritdoc IRWAAdapter
    function rulesEngine() external view override returns (address) {
        return address(_rulesEngine);
    }

    /**
     * @notice Get balance of an account
     */
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    /**
     * @notice Transfer tokens
     */
    function transfer(address to, uint256 amount) external whenNotPaused returns (bool) {
        _checkRules(msg.sender, to, amount, IContext.OperationType.TRANSFER);
        _transfer(msg.sender, to, amount);
        return true;
    }

    /**
     * @notice Get allowance
     */
    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @notice Approve spender
     */
    function approve(address spender, uint256 amount) external whenNotPaused returns (bool) {
        _checkRules(msg.sender, spender, amount, IContext.OperationType.APPROVE);
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice Transfer from
     */
    function transferFrom(address from, address to, uint256 amount) external whenNotPaused returns (bool) {
        _checkRules(from, to, amount, IContext.OperationType.TRANSFER);
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @notice Mint tokens (minter only)
     */
    function mint(address to, uint256 amount) external onlyMinter whenNotPaused {
        _checkRules(address(0), to, amount, IContext.OperationType.MINT);
        _mint(to, amount);
    }

    /**
     * @notice Burn tokens
     */
    function burn(uint256 amount) external whenNotPaused {
        _checkRules(msg.sender, address(0), amount, IContext.OperationType.BURN);
        _burn(msg.sender, amount);
    }

    /**
     * @notice Burn tokens from account (with allowance)
     */
    function burnFrom(address from, uint256 amount) external whenNotPaused {
        _checkRules(from, address(0), amount, IContext.OperationType.BURN);
        _spendAllowance(from, msg.sender, amount);
        _burn(from, amount);
    }

    /**
     * @notice Pause contract
     */
    function pause() external onlyAdmin {
        paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @notice Unpause contract
     */
    function unpause() external onlyAdmin {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /**
     * @notice Set minter role
     */
    function setMinter(address newMinter) external onlyAdmin {
        require(newMinter != address(0), "RWA_ERC20: invalid minter");
        minter = newMinter;
    }

    /**
     * @notice Check rules before operation
     */
    function _checkRules(
        address from,
        address to,
        uint256 amount,
        IContext.OperationType opType
    ) private {
        Context context = new Context(opType, from, to, amount, asset);
        IRulesEngine.EvaluationResult memory result = _rulesEngine.evaluate(context);

        if (!result.passed) {
            emit RuleCheckFailed(from, to, amount, result.failedRule, result.reason);
            revert(string(abi.encodePacked("RWA_ERC20: rule check failed - ", result.reason)));
        }

        emit RuleCheckPassed(from, to, amount, result.evaluatedRules);
    }

    /**
     * @notice Internal transfer
     */
    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "RWA_ERC20: transfer from zero address");
        require(to != address(0), "RWA_ERC20: transfer to zero address");
        require(_balances[from] >= amount, "RWA_ERC20: insufficient balance");

        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    /**
     * @notice Internal mint
     */
    function _mint(address to, uint256 amount) private {
        require(to != address(0), "RWA_ERC20: mint to zero address");

        totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    /**
     * @notice Internal burn
     */
    function _burn(address from, uint256 amount) private {
        require(from != address(0), "RWA_ERC20: burn from zero address");
        require(_balances[from] >= amount, "RWA_ERC20: insufficient balance");

        _balances[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    /**
     * @notice Internal approve
     */
    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "RWA_ERC20: approve from zero address");
        require(spender != address(0), "RWA_ERC20: approve to zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @notice Internal spend allowance
     */
    function _spendAllowance(address owner, address spender, uint256 amount) private {
        uint256 currentAllowance = _allowances[owner][spender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "RWA_ERC20: insufficient allowance");
            _approve(owner, spender, currentAllowance - amount);
        }
    }
}
