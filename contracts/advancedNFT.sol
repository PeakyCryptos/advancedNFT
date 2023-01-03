// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract advancedNFT is ERC721 {
    // default null
    // https://ipfs.io/ipfs/QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/
    // initalize as empty (unrevealed)
    string public baseURI;

    // total amount that could ever be minted
    uint256 immutable maxSupply;

    // when metadata will eligible to be revealed
    uint256 immutable maxRevealBlockHeight;

    // How many blocks back to use the hash of
    // i.e if reveal block height of 5 and we want to use up to 4 previous block hashes
    // reveal look back = 4: 5,4,3,2,1 (1-5)
    uint256 immutable revealLookBack;

    // reveal block height concatenate n blocks hash
    bytes32 public revealHash;

    // randomized starting index
    // i.e tokenId[0] maps to startingIndex
    uint256 startingIndex;

    // amount of tokens that are currently claimable via mint
    uint256 tokensLeftToMint;

    // event changed nickname

    // allows token owner to attatch a nickname to their nft
    // tokenId => nickName
    mapping(uint256 => string) tokenNickName;

    constructor(
        uint256 _maxSupply,
        uint256 _maxRevealBlockHeight,
        uint256 _revealLookBack
    ) ERC721("fairApes", "fApes") {
        // make sure revealBlockHeight occurs at least 48 hours after contract deployment
        // at roughly 15 seconds per block (11520 blocks = 2 days)
        require(_maxRevealBlockHeight > block.number + 11520);

        tokensLeftToMint = _maxSupply;
        maxSupply = _maxSupply;
        maxRevealBlockHeight = _maxRevealBlockHeight;
        revealLookBack = _revealLookBack;
    }

    function mint() external {
        require(msg.sender == tx.origin, "Only EOA");

        // check merkle for validity to mint**

        // use state machine instead **
        require(revealHash.length != 0, "reveal hash not calculated yet!");

        uint256 tokenId = uint256(
            keccak256(abi.encodePacked(block.timestamp, revealHash))
        ) % tokensLeftToMint;
        tokensLeftToMint -= 1;

        _mint(msg.sender, tokenId);
    }

    function constructRevealHash() external {
        // make sure reveal hash not already initalizaed
        require(revealHash != 0, "revealHash already set!");

        // check if ready to reveal
        uint256 minRevealBlock = maxRevealBlockHeight - revealLookBack;
        require(block.number > maxRevealBlockHeight, "Unable to reveal yet!");

        // must reveal before the farthest look back blockhash becomes void
        // valid hash of the given block only available for 256 most recent blocks
        require(block.number - minRevealBlock > 255, "Max look back expired!");

        // declare array of reveal block hashes
        bytes32[] memory revealBlockHashes = new bytes32[](revealLookBack + 1);

        // populate block hash array
        for (uint256 i = 0; i < revealLookBack; i++) {
            revealBlockHashes[i] = blockhash(maxRevealBlockHeight - i);
        }

        // set reveal hash
        revealHash = keccak256(abi.encodePacked(revealBlockHashes));
    }

    function setNickName(uint256 tokenId, string calldata _newNickName)
        external
    {
        // check nft ownership
        require(msg.sender == _ownerOf(tokenId));

        // set nickname
        tokenNickName[tokenId] = _newNickName;
    }

    function retrieveNickName(uint256 tokenId)
        external
        view
        returns (string memory)
    {
        return tokenNickName[tokenId];
    }

    // https://forum.openzeppelin.com/t/are-nft-projects-doing-starting-index-randomization-and-provenance-wrong-or-is-it-just-me/14147
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory _baseURI = _baseURI();
        uint256 _sequenceId;

        if (startingIndex > 0) {
            _sequenceId = (tokenId + startingIndex) % maxSupply;
            // wrap around to point to unminted id's metadata
            if (_sequenceId > maxSupply - 1) {
                _sequenceId -= maxSupply;
            }
            return string(abi.encodePacked(baseURI, _sequenceId));
        }

        // if startingIndex not set
        return "";
    }

    function _baseURI() internal pure override returns (string memory) {
        return "";
    }

    function setBaseURI(string calldata _newBaseURI) external {
        require(
            block.number > maxRevealBlockHeight,
            "Not ready to reveal yet!"
        );
        require(bytes(baseURI).length == 0, "URI data has already been set!");

        baseURI = _newBaseURI;
    }
}
