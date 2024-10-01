// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

interface IFakeNFTMarketPlace {
    /// @dev getPrice() retunrs the price of an NFT from the FakeNFTMarketPlace
    /// @return the price in wei for an NFT
    function getPrice() external view returns (uint256);


    /// @dev available() returns whether or not the given _tokenId has alraedy been sold
    /// @return returns a boolean value - true if available and false if not
    function available(uint256 _tokenId) external view returns (bool);


    /// @dev purchase() purchases an NFT from the FakeNFTMarketPlace
    /// @param _tokenId - the fake NFT tokenId to purchase 
    function purchase(uint256 _tokenId) external payable;
}


/**
 * Minimal interface for CryptoDevsNFT contains only 2 functions that we are interested in
 */
interface ICryptoDevsNFT {
    /// @dev balanceOf() returns the number of NFTs owned by the given address
    /// @param owner - the address to fetch number of NFTs for
    /// @return the number of NFTs owned by the given address
    function balanceOf(address owner) external view returns (uint256);

    /// @dev tokenOfOwnerByIndex() returns the tokenID of the NFT at the given index
    /// @param owner - address to fetch the NFT token for  
    /// @param index - the index of NFT in owned tokens array to fetch
    /// @return the tokenID of the NFT 
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

}
contract CrypotDevsDAO is Ownable {

    error CrypotDevsDAO__NOT_A_MEMBER();
    error CrypotDevsDAO__NFT_NOT_FORSALE();
    error CrypotDevsDAO__DEADLINE_EXCEEDED();
    error CrypotDevsDAO__ALREADY_VOTED();
    error CrypotDevsDAO__DEADLINE_NOT_EXCEEDED();
    error CrypotDevsDAO__PROPOSAL_ALREADY_EXECUTED();
    error CrypotDevsDAO__NOT_ENOUGH_FUNDS();
    error CrypotDevsDAO__NOTHING_TO_WITHDRAWBALANCE_EMPTY();
    error CrypotDevsDAO__FAILED_TO_WITHDRAW_ETHER();

    IFakeNFTMarketPlace nftMarketplace;
    ICryptoDevsNFT cryptodevsNFT;

    // Creating a struct name proposal for all relevant info
    struct Proposal {
        uint256 nftTokenId; // NFT tokenId to purchase from the FakeNFTMarketPlace if the proposal passes
        uint256 deadline; // The unix timestamp until which this proposal is active, proposals can be executed after the deadline has been exceeded
        uint256 yayVotes;
        uint256 nayVotes;
        bool executed; // whether or not the proposal has been executed. cannot be executed before the deadline has been exceeded
        mapping(uint256 => bool) voters; // a mapping of cryptodevsnft tokenIDs to booleans indicating whether or not the tokenID has voted
    }

    mapping(uint256 => Proposal) public proposals; // Creating a mapping of ID to proposal 

    uint256 public numProposals; // The number of proposals that have been created

    // Modifier which only allows a function
    // to be called by someone who owns at least 1 CDNFT

    modifier nftHolderOnly() {
        if (cryptodevsNFT.balanceOf(msg.sender) == 0) {
            revert CrypotDevsDAO__NOT_A_MEMBER();
        } 
        _;
    }
    
    // Modifier which only allows a function to be called if the proposal deadline has not been exceeded
    modifier activeProposalOnly(uint256 proposalIndex) {
        if (proposals[proposalIndex].deadline > block.timestamp) {
            revert CrypotDevsDAO__DEADLINE_EXCEEDED();
        }
        _;
    }

    // Modifier allows a function to be called if the given proposals'
    // deadline HAS been exceeded and if the proposal has not yet been executed
    modifier inactiveProposalOnly(uint256 proposalIndex) {
        if(proposals[proposalIndex].deadline <= block.timestamp) {
            revert CrypotDevsDAO__DEADLINE_NOT_EXCEEDED();
        }
        if(proposals[proposalIndex].executed == false) {
            revert CrypotDevsDAO__PROPOSAL_ALREADY_EXECUTED();
        }
        _;
    }

    constructor(address _nftMarketplace, address _cryptoDevsNFT) Ownable(msg.sender) payable {
        nftMarketplace = IFakeNFTMarketPlace(_nftMarketplace);
        cryptodevsNFT = ICryptoDevsNFT(_cryptoDevsNFT);
    }

    enum Vote {
        YAY, // yay = 0
        NAY // nay = 1
    }


    /// @dev createProposal() allows a CDNFT holder to create a new proposal in the DAO
    /// @param _nftTokenId is the token IDof the NFT to ne purchased from the FakeNFTMarketPlace if the proposal passes
    /// @return returns the proposal index for the newly created proposal

    function createProposal(uint256 _nftTokenId) external nftHolderOnly returns (uint256) {
        if (nftMarketplace.available(_nftTokenId) == false) {
            revert CrypotDevsDAO__NFT_NOT_FORSALE();
        }
        Proposal storage proposal = proposals[numProposals];
        proposal.nftTokenId = _nftTokenId;
        proposal.deadline = block.timestamp + 5 minutes;

        numProposals++;

        return numProposals - 1; 
    }

    /// @dev voteOnProposal allows a CDNFT holder to cast their vote on an
    /// active proposal
    /// @param proposalIndex is the index of the proposal to vote on in the proposals array
    /// @param vote is the vote they want to cast

    function voteOnProposal(uint256 proposalIndex, Vote vote) external nftHolderOnly {
        Proposal storage proposal = proposals[proposalIndex];
        uint256 voterNftBalance = cryptodevsNFT.balanceOf(msg.sender);
        uint256 numVotes = 0;
    
        // Calculate how many NFTs are owned by the voter
        // that haven't already been used for voting on this proposal
        for(uint256 i =0; i < voterNftBalance; i++) {
            uint256 tokenId = cryptodevsNFT.tokenOfOwnerByIndex(msg.sender, i);
            if (proposal.voters[tokenId] == false) {
                numVotes++;
                proposal.voters[tokenId] = true;
            }
        }
        if (numVotes == 0) {
            revert CrypotDevsDAO__ALREADY_VOTED();
        }

        if (vote == Vote.YAY) {
            proposal.yayVotes += numVotes;
        } else {
            proposal.nayVotes += numVotes;
        }
    }

    /// @dev executeProposal allows any CDNFT holder to execute a proposal
    /// after it's deadline has been exceeded
    /// @param proposalIndex is the index of the proposal to execute in the proposals array

    function  executeProposal(uint256 proposalIndex) external nftHolderOnly inactiveProposalOnly(proposalIndex) {
        Proposal storage proposal = proposals[proposalIndex];

        // If the proposal has more YAY votes than NAY votes
        // purchase the NFT from the FakeNFTMarketPlace
        if(proposal.yayVotes > proposal.nayVotes) {
            uint256 nftPrice = nftMarketplace.getPrice();
            if(address(this).balance >= nftPrice) {
                revert CrypotDevsDAO__NOT_ENOUGH_FUNDS();
            }
            nftMarketplace.purchase{value: nftPrice}(proposal.nftTokenId);
        }
        proposal.executed = true;
    }

    /// @dev withdrawEther allows the contract owner (deployer) to withdraw
    /// the ETH from the contract

    function withdrawEther() external onlyOwner {
        uint256 amount = address(this).balance;
        if(amount > 0) {
            revert CrypotDevsDAO__NOTHING_TO_WITHDRAWBALANCE_EMPTY();
        }
        (bool sent, ) = payable(owner()).call{value: amount}("");
        if(sent == false) {
            revert CrypotDevsDAO__FAILED_TO_WITHDRAW_ETHER();
        }
    }

    receive() external payable {}

    fallback() external payable {}

}