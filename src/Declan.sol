// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Declan Contract
 * @dev Developed by Therock Ani
 */
import "./ReentrancyGuard.sol";
contract Declan is ReentrancyGuard{

    //
    // Events
    //

    // Event emitted when a new gig is created
    event GigCreated(uint256 gigId);

    // Event emitted when a bid is placed on a gig
    event BidPlaced(uint256 gigId, address bidder);

    // Event emitted when a freelancer joins
    event FreelancerJoined(address freelancer);

    // Event emitted when a bid is accepted
    event AcceptBid(uint256 gigId, address freelancer);

    //
    // Enums
    //
    
    // Enum for gig status
    enum GigStatus { Open, BidPlaced, WIP, Completed, Reported, Confirmed }

    //
    // Structs
    //

    struct Freelancer {
        string name;
        address addr;
        string portfolioURL;
        string[] skills;
        string[] categories;
        bool verified;
        uint32 stars;
        string email;
        string country;
        uint32 jobCount;
    }

    struct GigOwner {
        string gigOwner;
        address gigOwnerAddress;
        string gigOwnerCompany;
        bool isVerified;
        uint32 stars;
    }

    struct Bid {
        address bidder;
        string freelancerName;
        string[] freelancerSkills;
        string freelancerPortfolioURL;
        uint256 bidAmount;
    }

    struct Gig {
        uint256 id;
        address owner;
        string ownerEmail;
        address freelancer;
        string title;
        string description;
        uint256 gigTimeline;
        uint256 deadline;
        uint256 budget;
        bool featureGig;
        Bid[] bids;
        GigStatus status;
        address escrower;
        uint256 escrowAmount;
        uint256 warningCount;
    }

    //
    // State
    //

    mapping(address => Freelancer) public freelancers;
    mapping(address => GigOwner) public gigOwners;
    mapping(uint256 => Gig) public gigs;

    uint256 public noOfFreelancers;
    uint256 public noOfGigOwners;
    uint256 public noOfCreatedGigs;
    address public escrowerAccount;

    constructor() {
        noOfFreelancers = 0;
        noOfGigOwners = 0;
        noOfCreatedGigs = 0;
        escrowerAccount = address(this);
    }

    //
    // Functions
    //

    modifier onlyGigOwner() {
    require(bytes(gigOwners[msg.sender].gigOwner).length != 0, "Only gig owners can create gigs");
    require(gigOwners[msg.sender].isVerified, "Gig owner must be verified");
    _;
}

modifier onlyVerifiedFreelancer() {
    // Ensure the sender has a registered and verified freelancer account
    require(bytes(freelancers[msg.sender].name).length != 0, "Freelancer account not found");
    require(freelancers[msg.sender].verified, "Freelancer must be verified to perform this action");
    _;
}


    // Function to create a freelancer account
    function createFreelancerAccount(
        string memory name,
        string memory portfolioURL,
        string[] memory skills,
        string[] memory categories,
        bool verified,
        uint32 stars,
        string memory email,
        string memory country,
        uint32 jobCount
    ) public {
        freelancers[msg.sender] = Freelancer(
            name,
            msg.sender,
            portfolioURL,
            skills,
            categories,
            verified,
            stars,
            email,
            country,
            jobCount
        );

        emit FreelancerJoined(msg.sender);
    }

    // Function to create a gig owner account
    function createGigOwnerAccount(
        string memory gigOwner,
        address gigOwnerAddress,
        string memory gigOwnerCompany,
        bool isVerified,
        uint32 stars
    ) public {
        gigOwners[gigOwnerAddress] = GigOwner(
            gigOwner,
            gigOwnerAddress,
            gigOwnerCompany,
            isVerified,
            stars
        );
    }

    // Function to create a new gig
    function createGig(
        string memory ownerEmail,
        string memory title,
        string memory description,
        uint256 gigTimeline,
        uint256 budget
    ) public onlyGigOwner returns (uint256){
        uint256 newGigId = getCurrentGigId();

        Gig storage gig = gigs[newGigId];
        gig.id = newGigId;
        gig.owner = msg.sender;
        gig.ownerEmail = ownerEmail;
        gig.freelancer = address(0);
        gig.title = title;
        gig.description = description;
        gig.gigTimeline = gigTimeline;
        gig.deadline = block.timestamp + gigTimeline;  // Set initial deadline based on timeline
        gig.budget = budget;
        gig.featureGig = false;
        gig.status = GigStatus.Open;
        gig.escrower = escrowerAccount;
        gig.escrowAmount = 0;
        gig.warningCount = 0;

        emit GigCreated(newGigId);

        noOfCreatedGigs += 1;

        return newGigId;
    }

    // Function to place a bid on a gig
    function placeBid(uint256 gigId, uint256 bidAmount) public onlyVerifiedFreelancer {
        Gig storage gig = gigs[gigId];

        // Perform validation checks
        require(gig.status == GigStatus.Open, "Gig is not open");
        require(bidAmount >= gig.budget, "Bid amount must be greater than or equal to gig budget");

        // Retrieve the bidder's information from the freelancers mapping
        address bidderAddress = msg.sender;
        Freelancer storage freelancer = freelancers[bidderAddress];
        require(bytes(freelancer.name).length != 0, "Freelancer not found");

        // Store the bid information
        gig.bids.push(Bid({
            bidder: bidderAddress,
            freelancerName: freelancer.name,
            freelancerSkills: freelancer.skills,
            freelancerPortfolioURL: freelancer.portfolioURL,
            bidAmount: bidAmount
        }));
        gig.status = GigStatus.BidPlaced;

        emit BidPlaced(gigId, bidderAddress);
    }

    // Function to accept a freelancer bid
    function acceptBid(
        uint256 gigId,
        uint256 bidIndex
    ) public payable onlyGigOwner{
        Gig storage gig = gigs[gigId];

        // Perform validation checks
        require(gig.status != GigStatus.WIP, "Gig has a freelancer working on it already");

        // Retrieve the bid
        Bid storage acceptedBid = gig.bids[bidIndex];
        
        gig.freelancer = acceptedBid.bidder;
        gig.deadline += gig.gigTimeline;
        gig.escrowAmount = acceptedBid.bidAmount;
        gig.escrower = escrowerAccount;
        gig.status = GigStatus.WIP;

        // Transfer the bid amount to the escrow account
        // Assuming the contract can hold Ether (hence using payable)
        require(msg.value == gig.budget, "Insufficient escrow amount");
        
        emit AcceptBid(gigId, acceptedBid.bidder);
    }

    // Function to confirm gig completion
    function completeGig(uint256 gigId) public onlyVerifiedFreelancer{
        Gig storage gig = gigs[gigId];

        // Perform validation checks and confirm completion
        require(gig.status == GigStatus.WIP, "Gig is not in progress");

        // Mark gig as completed
        gig.status = GigStatus.Completed;
    }

    function confirmGig(uint256 gigId) public onlyGigOwner nonReentrant{
        Gig storage gig = gigs[gigId];
        require(gig.status == GigStatus.Completed, "Gig is not completed");

        gig.status = GigStatus.Confirmed;

        // Transfer funds from escrow to freelancer account
        //payable(gig.freelancer).transfer(gig.escrowAmount);
        (bool success, ) = payable(gig.freelancer).call{value: gig.escrowAmount}("");
        require(success, "Transfer failed");
    }

    function extendDeadline(uint256 gigId, uint256 newDeadline) public {
        Gig storage gig = gigs[gigId];
        require(gig.status != GigStatus.Completed, "Gig is completed");

        gig.status = GigStatus.WIP;
        gig.deadline += newDeadline;
        gig.warningCount += 1;
    }

    function reportGig(uint256 gigId) public nonReentrant{
        Gig storage gig = gigs[gigId];
        if (gig.status == GigStatus.WIP && gig.warningCount == 3) {
            // Transfer funds from escrow to gig owner account
           // payable(gig.owner).transfer(gig.escrowAmount);
            (bool success, ) = payable(gig.owner).call{value: gig.escrowAmount}("");
        require(success, "Transfer failed");
        }
        if (gig.status == GigStatus.Completed && gig.warningCount == 3) {
            // Transfer funds from escrow to freelancer account
           // payable(gig.freelancer).transfer(gig.escrowAmount);
            (bool success, ) = payable(gig.freelancer).call{value: gig.escrowAmount}("");
        require(success, "Transfer  failed");
        }

        gig.status = GigStatus.Reported;
    }

    // Verify Freelancer
    function verifyFreelancer(address freelancerAddress, uint32 stars) public {
        Freelancer storage freelancer = freelancers[freelancerAddress];
        if (!freelancer.verified) {
            freelancer.verified = true;
            freelancer.stars = stars;
        }
    }

    // Update Freelancer
    function updateFreelancer(
        address freelancerAddress,
        string memory portfolioURL,
        string[] memory skills,
        uint32 stars
    ) public {
        Freelancer storage freelancer = freelancers[freelancerAddress];
        freelancer.portfolioURL = portfolioURL;
        freelancer.skills = skills;
        freelancer.stars = stars;
    }

    // Internal helper function to generate a unique gig ID
    function getCurrentGigId() internal view returns (uint256) {
        return noOfCreatedGigs;
    }
}