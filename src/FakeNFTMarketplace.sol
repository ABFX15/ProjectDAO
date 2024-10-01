// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

contract FakeNFTMarketplace {
    error FakeNFT__invalidValue();
    // @dev maintain a mapping of fake tokenID to owner address
    mapping(uint256 => address) public tokens;

    // @dev set the purchase price for each fake NFT
    uint256 nftPrice = 0.1 ether;

    // @dev purchase() accepts ETH and marks the owner of the given tokenID as the caller address
    // @param _tokenId - the fake NFT tokenId to purchase

    function purchase(uint256 _tokenId) external payable {
        if(msg.value == nftPrice) {
            tokens[_tokenId] = msg.sender;
        } else {
            revert FakeNFT__invalidValue();
        }
    }

    function getPrice() external view returns (uint256) {
        return nftPrice;
    }

    // @dev available()  checks wether the token has already been sol
    // @param _tokenId is the tokenId to check for 
    function available(uint256 _tokenId) external view returns (bool) {
        if (tokens[_tokenId] == address(0)) {
            return true;
        }
        return false;
    }
}