// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AdvancedNFT is ERC721, Ownable {
    //Library inherited from ERC721
    using Strings for uint256;

    // default null
    // https://ipfs.io/ipfs/QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/
    // initalize as empty (unrevealed)
    string public baseURI;

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

    //

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

        //_owner = msg.sender;
        maxSupply = _maxSupply;
        revealBlockHeight = _maxRevealBlockHeight;
        numRevealBlocks = _numRevealBlocks;
        mintPrice = _mintPrice;
    }

    // value can't be 0
    // user precalculate input of keccak256(abi.encodePacked(uint8 guess, uint256 salt))
    // optionally can check whitelist users with merkle validity here
    function commit(uint256 tokenId, bytes32 dataHash) external {
        // if state = commit phase

        // Ensure the requested tokenId is within range (0 -> maxSupply - 1)
        require(tokenId < maxSupply, "Invalid tokenId");

        // Ensure player has not previously comitted
        require(
            playerCommitted[msg.sender] == false,
            "You have already comitted!"
        );

        // ensure they enter a valid dataHash (non-zero values disallowed)
        require(dataHash != 0, "Must enter non-zero values");

        // initalize empty playerData struct in memory
        playerData memory _playerData;

        // Construct player data
        _playerData.player = msg.sender;
        _playerData.dataHash = dataHash;

        // push hashed guess
        contentionMapping[tokenId].push(_playerData);

        // Update committal status
        playerCommitted[msg.sender] = true;
    }

    // view all the players in the running for the tokenId
    function viewContention(uint256 tokenId)
        external
        view
        returns (playerData[] memory)
    {
        return contentionMapping[tokenId];
    }

    function commitHelper(uint8 guess, uint256 salt)
        external
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(guess, salt));
    }

    // ideally the index should be prefilled on the frontend
    function reveal(
        uint256 tokenId,
        uint256 index,
        uint8 guess,
        uint256 salt
    ) external {
        // if state = reveal phase

        // guess of zero is disallowed
        require(guess != 0, "guess must be a non-zero value!");

        // data of player at index
        playerData memory _playerData = contentionMapping[tokenId][index];

        // ensure revealer is revealing for themself
        require(
            msg.sender == _playerData.player,
            "You can only reveal your own commit!"
        );

        bytes32 _hashedCommitNumber = _playerData.dataHash;

        // Ensure they have a valid commit
        require(_hashedCommitNumber != 0, "Invalid commit!");

        // Ensure hashed commit matches with their reveal commit
        require(
            _hashedCommitNumber == keccak256(abi.encodePacked(guess, salt)),
            "Revealed guess and salt do not match hashed commit!"
        );

        // store their revealed guess
        contentionMapping[tokenId][index].guess = guess;

        // Set their hashed commit to 0 (not valid) so that they can't call reveal twice
        // disallows them from trying to run for additional tokenId's
        contentionMapping[tokenId][index].dataHash = 0;
    }

    function _viewMintWinner(uint256 tokenId) internal view returns (address) {
        // check merkle for validity to mint** don't need to as we do this in reveal phase
        // only those who won the
        require(revealHash != 0, "Winner cannot be revealed yet!");

        // use state machine instead **
        require(revealHash.length != 0, "reveal hash not calculated yet!");

        // get revealHash
        uint8 _randNum = uint8(uint256(revealHash));

        // anyone can call to settle
        // as there is no check to see if msg.sender is the one who is settling
        playerData[] memory _playerData = contentionMapping[tokenId];

        // Check which player guessed closest to the reveal hash
        // numbers which are above the reveal hash
        uint256 currClosestNum;
        address currWinner;
        for (uint256 i; i < _playerData.length; ++i) {
            uint8 currGuess = _playerData[i].guess;
            address currPlayer = _playerData[i].player;

            // Ensure player revealed
            // un-revealed guess is by default 0 (un-initalized)
            if (currGuess == 0) {
                continue;
            }

            // See if current guess is closer than previous guess
            // allow overflows for wrap around checking
            // i.e if random number is 200 a guess of 300 and 100 are equivalent
            uint8 result;
            unchecked {
                result = _randNum - currGuess;
            }

            if (currGuess > currClosestNum) {
                currClosestNum = currGuess;
                currWinner = currPlayer;
            }
        }

        return currWinner;
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

    // ** fix can call someone elses tokenId and claim winnings without paying mint fee
    // ** multidelegate issue
    // preferrable winner checks viewMintWinner and then mints for themself
    // Can't be abused by multidelegte call as
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
    function constructReveal() external {
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

        uint256 _sequenceId;

        if (startingIndex > 0) {
            _sequenceId = (tokenId + startingIndex) % maxSupply;

            // wrap around to point to unminted id's metadata
            if (_sequenceId > maxSupply - 1) {
                _sequenceId -= maxSupply;
            }

            return string(abi.encodePacked(_baseURI(), _sequenceId.toString()));
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

    function multiDelegatecall(bytes[] memory data)
        external
        payable
        returns (bytes[] memory results)
    {
        results = new bytes[](data.length);

        for (uint256 i; i < data.length; i++) {
            (bool ok, bytes memory res) = address(this).delegatecall(data[i]);
            require(ok, "Delegate call failed!");

            // store result in memory
            results[i] = res;
        }
    }
}
