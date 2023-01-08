pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

interface ERC721 {
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}

// Wrapper ontop of ERC721 contract which receives a token and sends back an ERC1155
// all tokenId's receive the same ERC1155 token
contract NFTWrapper is ERC1155, ERC721Holder {
    ERC721 public ERC721Contract;
    uint256 public immutable specialTokenId;

    // maps a ERC721 tokenId to it's current owner (as the official owner is this contract)
    mapping(uint256 => address) public balance721;

    constructor(address _ERC721Address, uint256 _specialTokenId)
        ERC1155("https://token-cdn-domain/{id}.json")
    {
        // wrapper for this specific ERC721 contract
        ERC721Contract = ERC721(_ERC721Address);

        // token id which is given for ERC721 receipt in this contract
        specialTokenId = _specialTokenId;
    }

    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes memory data
    ) public override returns (bytes4) {
        // check that only the ERC721 contract is calling this (public vulnerability)
        require(
            msg.sender == address(ERC721Contract),
            "Can only be called via the ERC721 contract!"
        );

        // log the receipt of their tokenId
        balance721[tokenId] = from;

        // mint all erc721 senders token 0 ( tokenId ERC721[any] -> ERC1155[0])
        _mint(from, specialTokenId, 1, data);

        //return this.onERC721Received.selector;
        return this.onERC721Received.selector;
    }

    /** @dev when transferring funds the bytes data for safeTransferFrom/Batch
     *  must be a uint256 array of all tokenId's they would like claim/transfer
     *  i.e if they want [0,1,10] back then the bytes data input would be:
     *
     *  0000000000000000000000000000000000000000000000000000000000000003
     *  0000000000000000000000000000000000000000000000000000000000000000
     *  0000000000000000000000000000000000000000000000000000000000000001
     *  000000000000000000000000000000000000000000000000000000000000000a
    
     *  first 32 bytes is length, followed by the each 32 bytes of the id
     */
    function _transferHelper(
        address from,
        address to,
        uint256 amount,
        bytes memory data
    ) internal {
        // check bytes data to see which ERC721 tokenId they are requesting back
        bytes memory _data = data;

        // amount of nft's being transfered/claimed
        uint256 length;

        // Where to start copying tokenId's from within bytes data
        bytes32 dataStartPos;
        assembly {
            // add 1 to length as we will skip the length ptr when looping
            // add 0x20 to _data as we must skip over the bytes length data
            length := mload(add(_data, 0x20))

            // pos to start at to skip to the array data elements
            dataStartPos := add(_data, 0x40)
        }

        // Ensure amount of ERC1155's they're sending matches 721's they're claiming
        require(amount == length, "Mismatch of ERC1155 to ERC721 claims");

        // loop over unpacked byte elements as if it were a solidity array
        uint256 currTokenId;
        for (uint256 i; i < length; i++) {
            assembly {
                // parse bytes to get this iterations tokenId
                currTokenId := mload(add(dataStartPos, mul(i, 0x20)))
            }
            require(
                balance721[currTokenId] == from,
                "You don't own the ERC721 being transferred!"
            );

            if (to == address(this)) {
                // reset token ownership claim
                balance721[currTokenId] = address(0);

                // transfer the ERC721 back to them if ERC1155 was sent to this contract
                // reverse from and to as we are sending the ERC721 from this contract
                ERC721Contract.safeTransferFrom(to, from, currTokenId);
            } else {
                // else update the tokenId balance mapping to the new owner
                balance721[currTokenId] = to;
            }
        }
    }

    // On transfers update tokenId to balance mapping in this contract
    // must specify in bytes data which tokenId they are transferring (see _transferHelper comments)
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override {
        // inherited logic
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        _safeTransferFrom(from, to, id, amount, data);

        // only transfer if the token they are sending is the special token
        // the token which is given for all ERC721 receivals
        if (id == specialTokenId) {
            // added logic to transfer tokenId they own
            _transferHelper(from, to, amount, data);

            // burn the ERC1155's that we got back
            _burn(address(this), id, amount);
        }
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);

        // check if they are transferring special token and perform the erc721 logging
        // This enables them to transfer many id's at once but when transferring special token
        // They must relinquish ownership of their matched erc721 as well
        for (uint256 i; i < ids.length; ++i) {
            if (ids[i] == specialTokenId) {
                // transfer ERC721 ownership
                _transferHelper(from, to, amounts[i], data);

                // burn the ERC1155's that we got back
                _burn(address(this), ids[i], amounts[i]);
            }
        }
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
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
