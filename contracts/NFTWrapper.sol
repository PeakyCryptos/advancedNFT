pragma solidity 0.8.17;

interface ERC721 {
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

// Wrapper ontop of ERC721 contract which receives a token and sends back an ERC1155
contract NFTWrapper is ERC1155 {
    ERC721 public ERC721Contract;

    // maps a tokenId to it's current owner
    mapping(uint256 => address) balance721;

    constructor(address _ERC721Address)
        ERC1155("https://token-cdn-domain/{id}.json")
    {
        // wrapper for this specific ERC721 contract
        ERC721Contract = ERC721(_ERC721Address);
    }

    // check that only the ERC721 contract is calling this (public vulnerability)
    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes memory data
    ) public virtual returns (bytes4) {
        // log the receipt of their tokenId
        balance721[tokenId] = from;

        // mint all erc721 senders token 0 ( tokenId ERC721[any] -> ERC1155[0])
        _mint(msg.sender, 0, 1, data);

        //return this.onERC721Received.selector;
        return IERC721Receiver.onERC721Received.selector;
    }

    /** @dev when transferring funds the bytes data for safeTransferFrom
     *  must be a uint256 array of all tokenId's they would like back
     *  i.e if they want [0,1,10] back then the bytes data input would be:
     *
     *  0000000000000000000000000000000000000000000000000000000000000003
     *  0000000000000000000000000000000000000000000000000000000000000000
     *  0000000000000000000000000000000000000000000000000000000000000001
     *  000000000000000000000000000000000000000000000000000000000000000a
    
     *  first 32 bytes is length, followed by the each 32 bytes of the id
     */
    // check that only the ERC1155 contract is calling this (public vulnerabilit
    function onERC1155Received(
        address,
        address from,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual returns (bytes4) {
        // check bytes data to see which ERC721 tokenId they are requesting back
        bytes memory _data = data;

        // prune bytes to get the amount of elements
        uint256 length;
        assembly {
            // add 1 to length as we will skip the length ptr when looping
            // add 0x20 to _data as we must skip over the bytes length data
            length := mload(add(_data, 0x20))
        }

        // Ensure amount of ERC1155's their sending matches 721's they're claiming
        //require(amount == length, "Mismatch of ERC1155 to ERC721 claims");

        // array to unpack these elements in
        uint256[] memory tokenIds = new uint256[](length);

        // unpack bytes to proper array format
        assembly {
            // pos to start at to skip to the array data elements
            let writeStartPos := add(tokenIds, 0x20)
            let dataStartPos := add(_data, 0x40)

            // store in scratch space ERC721 address mapping slot
            mstore(0x20, balance721.slot)

            // loop over unpacked byte elements and push them to the array
            for {
                let i := 0
            } lt(i, length) {
                i := add(i, 1)
            } {
                let tokenId := mload(add(dataStartPos, mul(i, 0x20)))

                // store the tokenId in scratch space
                mstore(0x00, tokenId)

                // check if sender owns specified tokenId's they are claiming
                // mapping data slot = keccak256(key,slot)
                let tokenDataSlotLocation := keccak256(0x00, 0x40)
                if iszero(eq(from, sload(tokenDataSlotLocation))) {
                    revert(0, 0)
                }

                // reset token ownership claim
                sstore(tokenDataSlotLocation, 0x0)
            }
        }

        // transfer the ERC721 back to them
        ERC721Contract.safeTransferFrom(address(this), from, id);

        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
