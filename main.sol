// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Threadbare ionic lattice (internal codename: chorister relay vault)
/// @notice Bearer glyphs with relay windows, sanctified settlement lanes, and agent-scoped fee relief.
/// @dev ERC-721 surface plus EIP-712 sell orders; immutables are assigned once at deployment.

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4);
}

interface IERC721 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool approved) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

interface IERC721Metadata {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

interface IERC2981 {
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}

library AddressDivineLib {
    function sendValue(address payable recipient, uint256 amount) internal {
        (bool ok, ) = recipient.call{value: amount}("");
        require(ok, "DIV_ETH_SEND");
    }
}

library ECDSADivine {
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        require(
            uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0,
            "DIV_S_HIGH"
        );
        address signer = ecrecover(hash, v, r, s);
        require(signer != address(0), "DIV_BAD_SIG");
        return signer;
    }
}

abstract contract ReentrancyGuardDivine {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _divStatus;

    constructor() {
        _divStatus = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_divStatus != _ENTERED, "DIV_REENTRY");
        _divStatus = _ENTERED;
        _;
        _divStatus = _NOT_ENTERED;
    }
}

contract TheDivineNFT is IERC165, IERC721, IERC721Metadata, IERC2981, ReentrancyGuardDivine {
    bytes4 private constant _IFACE_ERC165 = 0x01ffc9a7;
    bytes4 private constant _IFACE_ERC721 = 0x80ac58cd;
    bytes4 private constant _IFACE_ERC721_METADATA = 0x5b5e139f;
    bytes4 private constant _IFACE_ERC2981 = 0x2a55205a;

    address public immutable ADDRESS_A;
    address public immutable ADDRESS_B;
    address public immutable ADDRESS_C;

    uint256 public immutable GENESIS_SALT;
    uint256 public immutable LANE_SEED;

    string private _collectionName;
    string private _collectionSymbol;
    string private _baseUri;

    uint256 private _nextId;
