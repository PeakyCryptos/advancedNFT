/* resource:
    https://medium.com/@ItsCuzzo/using-merkle-trees-for-nft-whitelists-523b58ada3f9 
*/

// 1. Import libraries. Use `npm` package manager to install
const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");
const { ethers } = require("hardhat");

// 2. Collect list of wallet addresses from competition, raffle, etc.
// The ticket number is added to the address and then a hash of it is taken
// claimable address are listed in order of claimed ticket
// Store list of addresses in some data sheet (Google Sheets or Excel)
let whitelistAddresses = [
  // remix addresses
  "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
  "0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2",
  "0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db",
  "0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB",
  "0x17F6AD8Ef982297579C203069C1DbfFE4348c372",
  "0x5c6B0f7Bf3E7ce046039Bd8FABdfD3f9F5021678",
  "0x03C6FcED478cBbC9a4FAB34eF9f40767739D1Ff7",
  "0x03C6FcED478cBbC9a4FAB34eF9f40767739D1Ff7",
];

// 3. Create a new array of `leafNodes` by hashing all indexes of the `whitelistAddresses` -
// with the index of where the refrenced address is in the array using `keccak256`.
// Then creates a Merkle Tree object using keccak256 as the algorithm.
// The leaves, merkleTree, and rootHash are all PRE-DETERMINED prior to whitelist claim
// i.e whitelistAddresses[0] maps to a tokenId of 0
const leafNodes = whitelistAddresses.map((addr, index) => {
  const node = ethers.utils.solidityKeccak256(
    ["address", "uint256"],
    [addr, index]
  );
  return node;
});

const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true });

// 6. Get root hash of the `merkleeTree` in hexadecimal format (0x)
// Print out the Entire Merkle Tree.
const rootHash = merkleTree.getRoot();
console.log("Whitelist Merkle Tree\n", merkleTree.toString());
//console.log("Root Hash: ", rootHash);

// ***** ***** ***** ***** ***** ***** ***** ***** //

// CLIENT-SIDE: Use `msg.sender` address to query and API that returns the merkle proof
// required to derive the root hash of the Merkle Tree

// ✅ Positive verification of address
const claimingAddress = leafNodes[1];
// ❌ Change this address to get a `false` verification
// const claimingAddress = keccak256("0X5B38DA6A701C568545DCFCB03FCB875F56BEDDD6");

// `getHexProof` returns the neighbour leaf and all parent nodes hashes that will
// be required to derive the Merkle Trees root hash.
const hexProof = merkleTree.getHexProof(claimingAddress);
console.log(hexProof);

// ✅ - ❌: Verify is claiming address is in the merkle tree or not.
// This would be implemented in your Solidity Smart Contract
console.log(merkleTree.verify(hexProof, claimingAddress, rootHash));
