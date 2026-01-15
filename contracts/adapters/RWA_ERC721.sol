// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRWAAdapter} from "../interfaces/IRWAAdapter.sol";
import {IRulesEngine} from "../interfaces/IRulesEngine.sol";
import {IContext} from "../interfaces/IContext.sol";
import {Context} from "../core/Context.sol";

/**
 * @title RWA_ERC721
 * @notice RWA-compliant ERC721 token with rules engine integration
 * @dev Full ERC721 implementation with pre/post hooks for rule evaluation
 */
contract RWA_ERC721 is IRWAAdapter {
    string public name;
    string public symbol;

    IRulesEngine private immutable _rulesEngine;
    address public immutable override asset;
    bool public override paused;

    uint256 private _nextTokenId;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    address public admin;
    address public minter;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    modifier onlyAdmin() {
        require(msg.sender == admin, "RWA_ERC721: caller is not admin");
        _;
    }

    modifier onlyMinter() {
        require(msg.sender == minter, "RWA_ERC721: caller is not minter");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "RWA_ERC721: paused");
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        address rulesEngine_
    ) {
        name = name_;
        symbol = symbol_;
        _rulesEngine = IRulesEngine(rulesEngine_);
        asset = address(this);
        admin = msg.sender;
        minter = msg.sender;
        _nextTokenId = 1;
    }

    /// @inheritdoc IRWAAdapter
    function rulesEngine() external view override returns (address) {
        return address(_rulesEngine);
    }

    /**
     * @notice Get balance of owner
     */
    function balanceOf(address owner) external view returns (uint256) {
        require(owner != address(0), "RWA_ERC721: invalid owner");
        return _balances[owner];
    }

    /**
     * @notice Get owner of token
     */
    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "RWA_ERC721: invalid token ID");
        return owner;
    }

    /**
     * @notice Transfer token
     */
    function transferFrom(address from, address to, uint256 tokenId) external whenNotPaused {
        require(_isApprovedOrOwner(msg.sender, tokenId), "RWA_ERC721: not authorized");
        _checkRules(from, to, tokenId, IContext.OperationType.TRANSFER);
        _transfer(from, to, tokenId);
    }

    /**
     * @notice Safe transfer token
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external whenNotPaused {
        require(_isApprovedOrOwner(msg.sender, tokenId), "RWA_ERC721: not authorized");
        _checkRules(from, to, tokenId, IContext.OperationType.TRANSFER);
        _safeTransfer(from, to, tokenId, "");
    }

    /**
     * @notice Safe transfer token with data
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external whenNotPaused {
        require(_isApprovedOrOwner(msg.sender, tokenId), "RWA_ERC721: not authorized");
        _checkRules(from, to, tokenId, IContext.OperationType.TRANSFER);
        _safeTransfer(from, to, tokenId, data);
    }

    /**
     * @notice Approve address to transfer token
     */
    function approve(address to, uint256 tokenId) external whenNotPaused {
        address owner = ownerOf(tokenId);
        require(to != owner, "RWA_ERC721: approval to current owner");
        require(msg.sender == owner || isApprovedForAll(owner, msg.sender), "RWA_ERC721: not authorized");

        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    /**
     * @notice Set approval for all tokens
     */
    function setApprovalForAll(address operator, bool approved) external whenNotPaused {
        require(operator != msg.sender, "RWA_ERC721: approve to caller");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @notice Get approved address for token
     */
    function getApproved(uint256 tokenId) external view returns (address) {
        require(_owners[tokenId] != address(0), "RWA_ERC721: invalid token ID");
        return _tokenApprovals[tokenId];
    }

    /**
     * @notice Check if operator is approved for all
     */
    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @notice Mint new token
     */
    function mint(address to) external onlyMinter whenNotPaused returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _checkRules(address(0), to, tokenId, IContext.OperationType.MINT);
        _mint(to, tokenId);
        return tokenId;
    }

    /**
     * @notice Burn token
     */
    function burn(uint256 tokenId) external whenNotPaused {
        require(_isApprovedOrOwner(msg.sender, tokenId), "RWA_ERC721: not authorized");
        address owner = ownerOf(tokenId);
        _checkRules(owner, address(0), tokenId, IContext.OperationType.BURN);
        _burn(tokenId);
    }

    /**
     * @notice Pause contract
     */
    function pause() external onlyAdmin {
        paused = true;
    }

    /**
     * @notice Unpause contract
     */
    function unpause() external onlyAdmin {
        paused = false;
    }

    /**
     * @notice Set minter role
     */
    function setMinter(address newMinter) external onlyAdmin {
        require(newMinter != address(0), "RWA_ERC721: invalid minter");
        minter = newMinter;
    }

    /**
     * @notice Check rules before operation
     */
    function _checkRules(
        address from,
        address to,
        uint256 tokenId,
        IContext.OperationType opType
    ) private {
        Context context = new Context(opType, from, to, tokenId, asset);
        IRulesEngine.EvaluationResult memory result = _rulesEngine.evaluate(context);

        if (!result.passed) {
            emit RuleCheckFailed(from, to, tokenId, result.failedRule, result.reason);
            revert(string(abi.encodePacked("RWA_ERC721: rule check failed - ", result.reason)));
        }

        emit RuleCheckPassed(from, to, tokenId, result.evaluatedRules);
    }

    /**
     * @notice Internal transfer
     */
    function _transfer(address from, address to, uint256 tokenId) private {
        require(ownerOf(tokenId) == from, "RWA_ERC721: transfer from incorrect owner");
        require(to != address(0), "RWA_ERC721: transfer to zero address");

        delete _tokenApprovals[tokenId];

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /**
     * @notice Internal safe transfer
     */
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) private {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "RWA_ERC721: transfer to non ERC721Receiver");
    }

    /**
     * @notice Internal mint
     */
    function _mint(address to, uint256 tokenId) private {
        require(to != address(0), "RWA_ERC721: mint to zero address");
        require(_owners[tokenId] == address(0), "RWA_ERC721: token already minted");

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @notice Internal burn
     */
    function _burn(uint256 tokenId) private {
        address owner = ownerOf(tokenId);

        delete _tokenApprovals[tokenId];

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    /**
     * @notice Check if address is approved or owner
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) private view returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || _tokenApprovals[tokenId] == spender);
    }

    /**
     * @notice Check ERC721Receiver
     */
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) private returns (bool) {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch {
                return false;
            }
        } else {
            return true;
        }
    }

    /**
     * @notice Get total supply
     */
    function totalSupply() external view returns (uint256) {
        return _nextTokenId - 1;
    }
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}
