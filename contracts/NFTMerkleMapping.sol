// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./MerkleDrop.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract advancedNFT is ERC721, MerkleDrop {
    // default null
    // https://ipfs.io/ipfs/QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/
    // initalize as empty (unrevealed)
    string public baseURI;

    address owner;

    // total amount that could ever be minted
    uint256 public immutable maxSupply;

    // when metadata will eligible to be revealed
    uint256 public immutable revealBlockHeight;

    // How many blocks back to use the hash of
    // i.e if reveal block height of 5 and we want to use 4 block hashes
    // reveal look back = 4: 5,6,7,8
    uint256 public immutable numRevealBlocks;

    // amount of wei per mint
    uint256 public immutable mintPrice;

    // reveal block height concatenate n blocks hash
    bytes32 public revealHash =
        0x219f584cc9fa57d670a0e1d9eea4cc40c5d0d0cf5465c64f59525c0d0bc25218;

    // randomized starting index
    // i.e tokenId[0] maps to startingIndex
    uint256 public startingIndex;

    // player who is in the running for a tokenId
    struct playerData {
        address player;
        uint8 guess;
        // stores user precalculated keccak256(abi.encodePacked(number,salt))
        bytes32 dataHash;
    }

    // maps user desired tokenID => {address, guess}
    mapping(uint256 => playerData[]) contentionMapping;

    // Log of player commits
    mapping(address => bool) playerCommitted;

    // allows token owner to attatch a nickname to their nft
    // tokenId => nickName
    mapping(uint256 => string) public tokenName;

    // event changed nickname
    // event comitted hash
    // event revealed hash

    constructor(
        bytes32 merkleRoot,
        uint256 _maxSupply,
        uint256 _maxRevealBlockHeight,
        uint256 _numRevealBlocks,
        uint256 _mintPrice
    ) ERC721("fairApes", "fApes") MerkleDrop(merkleRoot) {
        // make sure revealBlockHeight occurs at least 48 hours after contract deployment
        // at roughly 15 seconds per block (11520 blocks = 2 days)
        //    require(_maxRevealBlockHeight > block.number + 11520);

        owner = msg.sender;
        maxSupply = _maxSupply;
        revealBlockHeight = _maxRevealBlockHeight;
        numRevealBlocks = _numRevealBlocks;
        mintPrice = _mintPrice;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner!");
        _;
    }

    // Players call this function to know who the winner is
    // useful for players to know if they are the winner for the Id
    // before they settle the minting process for that Id
    // can always call View Mint Winner but can only mint once reveal phase is done
    // no incentive to reveal if they won first
    // players can compute off-chain with their current un-revealed guess against other players who have revealed to see if they win
    // if they know they will not win beforehand they can choose not to reveal to save themself some gas
    function viewMintWinner(uint256 tokenId) external view returns (address) {
        return _viewMintWinner(tokenId);
    }

    // preferrable winner checks viewMintWinner and then mints for themself
    function mint(uint256 tokenId) external payable {
        // if state = minting phase (after revealHash has been calculated)

        require(msg.sender == tx.origin, "Only EOA");

        // only pay during mint
        require(msg.value == mintPrice);

        // get the winner for this tokenId
        address currWinner = _viewMintWinner(tokenId);

        // ensure there is a valid player
        require(currWinner != address(0), "Invalid winner!");

        // only allows mints during mint phase with there being at least one person in the running
        _mint(currWinner, tokenId);
    }

    // get reveal hash used for mint settlement rand
    // get startingIndex used for random start point in nft minting
    // minting tokenId of 0 does not map to the ipfs collection image of 0 by default
    function constructReveal() external returns (bytes32[] memory, bytes32) {
        // make sure reveal hash not already initalizaed
        require(revealHash == 0, "revealHash already set!");

        // check if ready to reveal
        require(
            block.number > revealBlockHeight + numRevealBlocks,
            "Unable to reveal yet!"
        );

        // declare array of reveal block hashes
        bytes32[] memory revealBlockHashes = new bytes32[](numRevealBlocks);

        // populate block hash array
        for (uint256 i = 0; i < numRevealBlocks; i++) {
            bytes32 _currBlockHash = blockhash(revealBlockHeight + i);

            // Ensure block hash checked is valid
            // must execute before the minimum look back blockhash becomes void
            // valid hash of the given block only available for 256 most recent blocks
            require(_currBlockHash != 0, "Error! invalid block hash");

            revealBlockHashes[i] = _currBlockHash;
        }

        // set mint starting index
        startingIndex = uint8(uint256(revealHash));
    }

    function setNickName(uint256 tokenId, string calldata _newNickname)
        external
    {
        // check nft ownership
        require(msg.sender == ownerOf(tokenId));

        // set nickname
        tokenName[tokenId] = _newNickname;
    }

    function retrieveNickName(uint256 tokenId)
        external
        view
        returns (string memory)
    {
        return tokenName[tokenId];
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
        return "Not revealed yet!";
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string calldata _newBaseURI) external onlyOwner {
        // ensure minting phase is over
        require(block.number > revealBlockHeight, "Not ready to reveal yet!");

        require(bytes(baseURI).length == 0, "URI data has already been set!");

        baseURI = _newBaseURI;
    }
}
