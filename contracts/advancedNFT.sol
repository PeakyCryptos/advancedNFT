// contracts/GameItem.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract advancedNFT is ERC721 {

    // default null
    // https://ipfs.io/ipfs/QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/
    // initalize as empty (unrevealed)
    string public baseURI = "";

    // when metadata will eligible to be revealed
    uint256 immutable maxRevealBlockHeight;

    // How many blocks back to use the hash of
    // i.e if reveal block height of 5 and we want to use up to 4 previous block hashes
    // reveal look back = 4: 5,4,3,2,1 (1-5)
    uint256 immutable revealLookBack;

    // reveal block height concatenate n blocks hash
    bytes32 public revealHash;

    // amount of tokens that are currently claimable via mint
    uint256 tokensLeftToMint;

    // event changed nickname

    // allows token owner to attatch a nickname to their nft
    // tokenId => nickName
    mapping(uint256 => string) tokenNickName;

    constructor(uint256 _maxRevealBlockHeight, uint256 _revealLookBack) ERC721("fairApes", "fApes") {
        // make sure revealBlockHeight occurs at least 48 hours after contract deployment
        // at roughly 15 seconds per block (11520 blocks = 2 days)
        require(_maxRevealBlockHeight > block.number + 11520);
        
        tokensLeftToMint = 200;
        maxRevealBlockHeight = _maxRevealBlockHeight;
        revealLookBack = _revealLookBack;
    }

    function mint() external {
        require(msg.sender == tx.origin, "Only EOA");
       
        // check merkle for validity to mint**

        // use state machine instead **
        require(revealHash.length != 0, "reveal hash not calculated yet!");
        

        uint256 tokenId = uint256(keccak256(abi.encodePacked(msg.sender, revealHash))) % tokensLeftToMint;
        tokensLeftToMint -= 1;

        _mint(msg.sender, tokenId);
    }

    function constructRevealHash() external {
        uint256 minRevealBlock =  maxRevealBlockHeight - revealLookBack;
        require(block.number > maxRevealBlockHeight, "Unable to reveal yet!");

        // must reveal before the farthest look back blockhash becomes void
        // valid hash of the given block only available for 256 most recent blocks
        require(block.number - minRevealBlock > 255, "Max look back expired!");

        // declare array of reveal block hashes
        bytes32[] memory revealBlockHashes = new bytes32[](revealLookBack);

        // populate block hash array
        for (uint i=0; i < revealLookBack; i++) {
            revealBlockHashes[i] = blockhash(maxRevealBlockHeight - i);
        }


    }

    function setNickName(uint256 tokenId, string calldata _newNickName) external {
        // check nft ownership
        require(msg.sender == _ownerOf(tokenId));

        // set nickname
        tokenNickName[tokenId] = _newNickName;
    }

    function retrieveNickName(uint256 tokenId) external view returns(string memory) {
        return tokenNickName[tokenId];
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string calldata _newBaseURI) external {
        require(block.number > maxRevealBlockHeight, "Not ready to reveal yet!");
        require(bytes(baseURI).length == 0, "URI data has already been set!");

        baseURI = _newBaseURI; 
    }
}
