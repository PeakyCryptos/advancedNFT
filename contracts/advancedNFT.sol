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
    uint256 immutable revealBlockHeight;

    // How many blocks back to use the hash of
    // i.e if reveal block height of 5 and we want to use 4 block hashes
    // reveal look back = 4: 5,6,7,8
    uint256 immutable numRevealBlocks;

    // amount of wei per mint
    uint256 immutable mintPrice;

    // reveal block height concatenate n blocks hash
    bytes32 public revealHash;

    // randomized starting index
    // i.e tokenId[0] maps to startingIndex
    uint256 startingIndex;

    // stores user precalculated keccak256(abi.encodePacked(number,salt))
    mapping(address => bytes32) hashedCommitNumber;

    // maps user desired tokenID => adresses that want this ID
    // (What they are all competing for)
    mapping(uint256 => address[]) contentionMapping;

    // allows token owner to attatch a nickname to their nft
    // tokenId => nickName
    mapping(uint256 => string) tokenNickName;

    // event changed nickname
    // event comitted hash
    // event revealed hash

    constructor(
        uint256 _maxSupply,
        uint256 _maxRevealBlockHeight,
        uint256 _numRevealBlocks,
        uint256 _mintPrice
    ) ERC721("fairApes", "fApes") {
        // make sure revealBlockHeight occurs at least 48 hours after contract deployment
        // at roughly 15 seconds per block (11520 blocks = 2 days)
        //    require(_maxRevealBlockHeight > block.number + 11520);

        maxSupply = _maxSupply;
        revealBlockHeight = _maxRevealBlockHeight;
        numRevealBlocks = _numRevealBlocks;
        mintPrice = _mintPrice;
    }

    // value can't be 0
    // user precalculate input of keccak256(abi.encodePacked(uint256 number, uint256 salt))
    // check merkle validity here
    function commit(bytes32 dataHash) external {
        // if state = commit phase

        // check merkle validity
        // only whitelisted users can commit

        // cache mapping locally
        bytes32 _hashedCommitNumber = hashedCommitNumber[msg.sender];

        // ensure they are not trying to set a guess of 0
        require(dataHash != 0);

        // ensure they have not already comitted a guess
        require(_hashedCommitNumber == 0);

        // set their commit
        hashedCommitNumber[msg.sender] = dataHash;
    }

    // only meant to be called once so they are locked to a specific tokenId
    function reveal(
        uint256 tokenId,
        uint256 number,
        uint256 salt
    ) external {
        // if state = reveal phase

        bytes32 _hashedCommitNumber = hashedCommitNumber[msg.sender];

        // Ensure they have a valid commit
        require(_hashedCommitNumber != 0);

        // Ensure hashed commit matches with their reveal commit
        require(
            _hashedCommitNumber == keccak256(abi.encodePacked(number, salt))
        );

        // store their revealed guess
        contentionMapping[tokenId].push(msg.sender);

        // Set their hashedCommitNumber to 0 (not valid) so that they can't call reveal twice
        // disallows them from trying to run for additional tokenId's
        hashedCommitNumber[msg.sender] = 0;
    }

    function mint(uint256 tokenId) external payable {
        // if state = minting phase (after revealHash has been calculated)
        require(msg.sender == tx.origin, "Only EOA");

        // only pay during mint
        require(msg.value == mintPrice);

        // check merkle for validity to mint** don't need to as we do this in reveal phase
        // only those who won the

        // use state machine instead **
        require(revealHash.length != 0, "reveal hash not calculated yet!");

        // anyone can call to settle
        // as there is no check to see if msg.sender is the one who is settling
        address[] memory _players = contentionMapping[tokenId];

        uint256 tempClosestNum = 0;
        for (uint256 i; i < _players.length; ++i) {
            //contentionMapping[];
        }

        _mint(msg.sender, tokenId);
    }

    function constructRevealHash()
        external
        returns (bytes32[] memory, bytes32)
    {
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

        // set reveal hash
        revealHash = keccak256(abi.encodePacked(revealBlockHashes));

        return (revealBlockHashes, revealHash);
    }

    function setNickName(uint256 tokenId, string calldata _newNickName)
        external
    {
        // check nft ownership
        require(msg.sender == ownerOf(tokenId));

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
        require(block.number > revealBlockHeight, "Not ready to reveal yet!");

        require(bytes(baseURI).length == 0, "URI data has already been set!");

        baseURI = _newBaseURI;
    }
}
