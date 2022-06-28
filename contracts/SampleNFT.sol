// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./utils/NativeMetaTransaction.sol";
import "./utils/ContextMixin.sol";

contract OwnableDelegateProxy {}

/**
 * Used to delegate ownership of a contract to another address, to save on unneeded transactions to approve contract use for users
 */
contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

contract SampleNFT is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    ERC721Burnable,
    AccessControl,
    NativeMetaTransaction,
    ERC721Royalty,
    ContextMixin
{
    using Counters for Counters.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    Counters.Counter private _tokenIdCounter;

    // Custom Variable
    string public contractURI;
    uint96 public royaltyFee = 250;
    address public royaltyReceiver = 0x1A78b07cF867F4BBb708479C17669a56C8a9a2a3;
    address proxyRegistryAddress;
    address public owner;

    constructor(
        string memory name,
        string memory symbol,
        string memory _contractURI,
        address _proxyRegistryAddress
    ) ERC721(name, symbol) NativeMetaTransaction(name) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        owner = msg.sender;
        contractURI = _contractURI;
        proxyRegistryAddress = _proxyRegistryAddress;
        _setDefaultRoyalty(royaltyReceiver, royaltyFee);
    }

    function safeMint(address to, string memory uri)
        public
        onlyRole(MINTER_ROLE)
    {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage, ERC721Royalty)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl, ERC721Royalty)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // Custom Functions

    function setContractURI(string memory _uri)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        contractURI = _uri;
    }

    function updateTokenURI(uint256 _tokenId, string memory _uri)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setTokenURI(_tokenId, _uri);
    }

    function updateDefaultRoyalityInfo(
        address _royaltyReceiver,
        uint96 _royaltyFee
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        royaltyReceiver = _royaltyReceiver;
        royaltyFee = _royaltyFee;
        _setDefaultRoyalty(_royaltyReceiver, _royaltyFee);
    }

    function setTokenRoyalityInfo(
        uint256 _tokenId,
        address _royaltyReceiver,
        uint96 _royaltyFee
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        _setTokenRoyalty(_tokenId, _royaltyReceiver, _royaltyFee);
    }

    /**
     * Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-less listings.
     */
    function isApprovedForAll(address _owner, address operator)
        public
        view
        override(ERC721, IERC721)
        returns (bool)
    {
        // Whitelist OpenSea proxy contract for easy trading.
        ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
        if (address(proxyRegistry.proxies(_owner)) == operator) {
            return true;
        }

        return super.isApprovedForAll(_owner, operator);
    }

    function updateOwner(address _owner) external onlyRole(DEFAULT_ADMIN_ROLE) {
        owner = _owner;
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenIDsByAddress}.
     */
    function tokenIDsByAddress(address _owner)
        public
        view
        virtual
        returns (uint256[] memory)
    {
        uint256 length = ERC721.balanceOf(_owner);
        uint256[] memory userToken = new uint256[](length);
        if (length > 0) {
            for (uint256 i = 0; i < length; i++) {
                userToken[i] = ERC721Enumerable.tokenOfOwnerByIndex(_owner, i);
            }
        }
        return userToken;
    }

    // This is to support Native meta transactions
    // never use msg.sender directly, use _msgSender() instead
    function _msgSender() internal view override returns (address sender) {
        return ContextMixin.msgSender();
    }
}
