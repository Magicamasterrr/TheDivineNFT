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
    uint256 private _burnCount;

    uint256[] private _inventoryIds;
    mapping(uint256 => uint256) private _inventoryPos;

    uint256 public constant CELESTIAL_CAP = 16247;
    uint256 public constant MIN_OFFERING_WEI = 0.00042 ether;
    uint256 public constant SANCTIFIED_FEE_BPS = 185;
    uint256 public constant ROYALTY_BPS = 690;
    uint256 public constant MAX_AGENT_DISCOUNT_BPS = 5000;
    uint256 public constant PULSE_COOLDOWN_BLOCKS = 3;
    uint256 public constant MAX_BATCH = 64;

    bytes32 public constant ORDER_TYPEHASH = keccak256(
        "DivineOrder(uint256 tokenId,uint256 priceWei,uint256 nonce,uint256 deadline,address buyer)"
    );
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private immutable _DOMAIN_SEPARATOR;
    mapping(address => uint256) public orderNonce;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    mapping(uint256 => string) private _tokenUris;

    mapping(address => uint256) private _agentDiscountBps;
    mapping(address => uint64) private _agentBlessedAt;
    mapping(address => uint256) private _lastPulseBlock;

    mapping(bytes32 => bool) private _laneCommitUsed;
    uint256 private _pulseSeq;

    bool private _paused;
    uint256 public floorWeiHint;

    bytes32 private constant _H1 = 0xcd635568f35df078c497e8f2c3ecf9503ebc2ad61a31066b27846a086b73fdcb;
    bytes32 private constant _H2 = 0x211515bd8e928b7e0120d6200da988a2c9771fa78be19e587490c95151d94ef9;
    bytes32 private constant _H3 = 0x0e7e1220b8c6b23abf0e0886f0f9c8c70e8ee1871cf6b4cc77e96bb9fcc189a5;
    bytes32 private constant _H4 = 0x9a50816ca6e9c9efc3dab99c7489cdfddd89613f821ce1c4c372244f8ea10763;
    bytes32 private constant _H5 = 0xec788b541f1079977d6f85ef847d67fbe2457ec67ccd8453e7ec57a331eda47f;

    error DIV_BadInterface();
    error DIV_ZeroAddress();
    error DIV_NotOwnerNorApproved();
    error DIV_TransferToZero();
    error DIV_TokenAbsent(uint256 id);
    error DIV_CapReached(uint256 cap);
    error DIV_BadOffering(uint256 got, uint256 need);
    error DIV_Paused();
    error DIV_NotADDRESS_A();
    error DIV_NotADDRESS_C();
    error DIV_NotTokenOwner(uint256 id, address caller);
    error DIV_ApproveToOwner();
    error DIV_ApproveCallerNotOwner();
    error DIV_InvalidReceiver(address to);
    error DIV_SafeTransferRejected();
    error DIV_BadNonce(uint256 want, uint256 got);
    error DIV_OrderExpired(uint256 deadline, uint256 nowTs);
    error DIV_PriceMismatch(uint256 want, uint256 got);
    error DIV_BuyerMismatch(address want, address got);
    error DIV_LaneReplay();
    error DIV_PulseSpam();
    error DIV_BadDiscount(uint256 bps);
    error DIV_StringTooLong();
    error DIV_NoEthUnexpected();
    error DIV_SliceRange(uint256 start, uint256 count, uint256 supply);
    error DIV_BatchTooLarge(uint256 got, uint256 maxAllowed);

    event CelestialMint(address indexed to, uint256 indexed tokenId, bytes32 indexed haloTag, uint256 offering);
    event GlyphBurned(address indexed from, uint256 indexed tokenId, bytes32 indexed ashTag);
    event BaseUriRotated(string newBase);
    event PauseFlipped(bool paused);
    event FloorHintUpdated(uint256 weiHint);
    event AgentBlessed(address indexed agent, uint256 discountBps, uint256 whenTs);
    event AgentStripped(address indexed agent);
    event SanctifiedSale(
        uint256 indexed tokenId,
        address indexed seller,
        address indexed buyer,
        uint256 grossWei,
        uint256 feeWei,
        bytes32 pulseTag
    );
    event RelayPulse(address indexed emitter, uint256 indexed tokenId, bytes32 tag, bytes32 payload, uint256 seq);
    event LaneCommitSealed(address indexed relayer, bytes32 commit, uint256 whenTs);
    event EthSwept(address indexed to, uint256 amount);
    event LaneSignal(address indexed signer, bytes32 blob, uint256 whenTs);

    modifier whenNotPaused() {
        if (_paused) revert DIV_Paused();
        _;
    }

    modifier onlyADDRESS_A() {
        if (msg.sender != ADDRESS_A) revert DIV_NotADDRESS_A();
        _;
    }

    modifier onlyADDRESS_C() {
        if (msg.sender != ADDRESS_C) revert DIV_NotADDRESS_C();
        _;
    }

    constructor() {
        ADDRESS_A = 0xB895Ff11816228Aa91cF1a361Ae598e40B9Ab386;
        ADDRESS_B = 0x8E1C317575E0C03F312CffeDca5B5c6757e51E08;
        ADDRESS_C = 0x0612167B6870A7138eB78B5a02d5928c90C48C3f;
        GENESIS_SALT = 0x000000000000000000000000000000000000000000000000000000009c4f2a11d7;
        LANE_SEED = 0x0000000000000000000000000000000000000000000000000000000041e8b903c1;
        _collectionName = "TheDivineNFT";
        _collectionSymbol = "DIVN";
        _baseUri = "https://glazocode.dev/divine/meta/v1/";
        _nextId = 1;
        _paused = false;
        _DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(_collectionName)),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return
            interfaceId == _IFACE_ERC165 ||
            interfaceId == _IFACE_ERC721 ||
            interfaceId == _IFACE_ERC721_METADATA ||
            interfaceId == _IFACE_ERC2981;
    }

    function name() external view override returns (string memory) {
        return _collectionName;
    }

    function symbol() external view override returns (string memory) {
        return _collectionSymbol;
    }

    function paused() external view returns (bool) {
        return _paused;
    }

    function totalMinted() external view returns (uint256) {
        return _nextId - 1;
    }

    function totalBurned() external view returns (uint256) {
        return _burnCount;
    }

    function circulatingSupply() external view returns (uint256) {
        return (_nextId - 1) - _burnCount;
    }

    function totalSupply() external view returns (uint256) {
        return _inventoryIds.length;
    }

    function tokenByIndex(uint256 index) external view returns (uint256) {
        require(index < _inventoryIds.length, "DIV_BAD_INDEX");
        return _inventoryIds[index];
    }

    function baseURI() external view returns (string memory) {
        return _baseUri;
    }

    function agentDiscountBps(address agent) external view returns (uint256) {
        return _agentDiscountBps[agent];
    }

    function agentBlessedAt(address agent) external view returns (uint256) {
        return _agentBlessedAt[agent];
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _DOMAIN_SEPARATOR;
    }

    function pulseSequence() external view returns (uint256) {
        return _pulseSeq;
    }

    function balanceOf(address owner) external view override returns (uint256) {
        if (owner == address(0)) revert DIV_ZeroAddress();
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        address o = _owners[tokenId];
        if (o == address(0)) revert DIV_TokenAbsent(tokenId);
        return o;
    }

    function getApproved(uint256 tokenId) public view override returns (address) {
        _requireMinted(tokenId);
        return _tokenApprovals[tokenId];
    }

    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function approve(address to, uint256 tokenId) public override whenNotPaused {
        address owner = ownerOf(tokenId);
        if (to == owner) revert DIV_ApproveToOwner();
        if (msg.sender != owner && !isApprovedForAll(owner, msg.sender)) revert DIV_ApproveCallerNotOwner();
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) public override whenNotPaused {
        if (operator == msg.sender) revert DIV_ZeroAddress();
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override whenNotPaused {
        _transfer(from, to, tokenId, false, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override whenNotPaused {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        override
        whenNotPaused
    {
        _transfer(from, to, tokenId, true, data);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireMinted(tokenId);
        string memory explicitUri = _tokenUris[tokenId];
        if (bytes(explicitUri).length > 0) {
            return explicitUri;
        }
        return string(abi.encodePacked(_baseUri, _toString(tokenId)));
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        _requireMinted(tokenId);
        receiver = ADDRESS_B;
        royaltyAmount = (salePrice * ROYALTY_BPS) / 10_000;
    }

    function previewSanctifiedFeeWei(address buyerAgent, uint256 grossWei) external view returns (uint256) {
        uint256 feeBps = SANCTIFIED_FEE_BPS;
        uint256 discount = _agentDiscountBps[buyerAgent];
        if (discount > feeBps) {
            return 0;
        }
        feeBps -= discount;
        return (grossWei * feeBps) / 10_000;
    }

    function previewRoyaltyWei(uint256 tokenId, uint256 salePrice) external view returns (uint256) {
        _requireMinted(tokenId);
        return (salePrice * ROYALTY_BPS) / 10_000;
    }

    function laneEntropyMix(bytes32 tag) external view returns (bytes32) {
        return keccak256(abi.encode(tag, _H1, _H2, LANE_SEED, GENESIS_SALT));
    }

    function interfaceTags()
        external
        pure
        returns (bytes4 erc165, bytes4 erc721, bytes4 erc721Meta, bytes4 erc2981)
    {
        erc165 = _IFACE_ERC165;
        erc721 = _IFACE_ERC721;
        erc721Meta = _IFACE_ERC721_METADATA;
        erc2981 = _IFACE_ERC2981;
    }

    function batchOwnerOf(uint256[] calldata ids) external view returns (address[] memory out) {
        if (ids.length > MAX_BATCH) revert DIV_BatchTooLarge(ids.length, MAX_BATCH);
        out = new address[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            address o = _owners[id];
            if (o == address(0)) revert DIV_TokenAbsent(id);
            out[i] = o;
        }
    }

    function batchBalanceOf(address[] calldata addrs) external view returns (uint256[] memory out) {
        if (addrs.length > MAX_BATCH) revert DIV_BatchTooLarge(addrs.length, MAX_BATCH);
        out = new uint256[](addrs.length);
        for (uint256 i = 0; i < addrs.length; i++) {
            address a = addrs[i];
            if (a == address(0)) revert DIV_ZeroAddress();
            out[i] = _balances[a];
        }
    }

    function batchTokenURI(uint256[] calldata ids) external view returns (string[] memory out) {
        if (ids.length > MAX_BATCH) revert DIV_BatchTooLarge(ids.length, MAX_BATCH);
        out = new string[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            out[i] = tokenURI(ids[i]);
        }
    }

    function exportInventorySlice(uint256 start, uint256 count) external view returns (uint256[] memory slice) {
        if (count > MAX_BATCH) revert DIV_BatchTooLarge(count, MAX_BATCH);
        uint256 supply = _inventoryIds.length;
        if (start > supply) revert DIV_SliceRange(start, count, supply);
        uint256 end = start + count;
        if (end > supply) revert DIV_SliceRange(start, count, supply);
        slice = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            slice[i] = _inventoryIds[start + i];
        }
    }

    function isLaneCommitConsumed(bytes32 commit) external view returns (bool) {
        return _laneCommitUsed[commit];
    }

    function currentSellerNonce(address seller) external view returns (uint256) {
        return orderNonce[seller];
    }

    function quoteSanctifiedSettlement(address buyerAgent, uint256 grossWei)
        external
        view
        returns (uint256 feeWei, uint256 netSellerWei)
    {
        uint256 feeBps = SANCTIFIED_FEE_BPS;
        uint256 discount = _agentDiscountBps[buyerAgent];
        if (discount > feeBps) {
            feeBps = 0;
        } else {
            feeBps -= discount;
        }
        feeWei = (grossWei * feeBps) / 10_000;
