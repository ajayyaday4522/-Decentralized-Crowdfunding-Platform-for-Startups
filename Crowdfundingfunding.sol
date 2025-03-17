// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title StartupCrowdfunding
 * @dev A decentralized crowdfunding platform for startups
 */
contract StartupCrowdfunding {
    struct Campaign {
        address owner;
        string title;
        string description;
        uint256 fundingGoal;
        uint256 deadline;
        uint256 totalFunds;
        bool goalReached;
        bool fundsClaimed;
        mapping(address => uint256) contributions;
    }

    uint256 public campaignCount;
    mapping(uint256 => Campaign) public campaigns;
    uint256 public platformFee = 2; // 2% platform fee

    event CampaignCreated(uint256 campaignId, address owner, string title, uint256 fundingGoal, uint256 deadline);
    event ContributionMade(uint256 campaignId, address contributor, uint256 amount);
    event FundsClaimed(uint256 campaignId, address owner, uint256 amount);
    event RefundClaimed(uint256 campaignId, address contributor, uint256 amount);

    /**
     * @dev Creates a new crowdfunding campaign
     * @param _title Campaign title
     * @param _description Campaign description
     * @param _fundingGoal Funding target in wei
     * @param _durationInDays Campaign duration in days
     */
    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _fundingGoal,
        uint256 _durationInDays
    ) external {
        require(_fundingGoal > 0, "Funding goal must be greater than 0");
        require(_durationInDays > 0 && _durationInDays <= 90, "Duration must be between 1 and 90 days");

        uint256 campaignId = campaignCount;
        Campaign storage newCampaign = campaigns[campaignId];
        
        newCampaign.owner = msg.sender;
        newCampaign.title = _title;
        newCampaign.description = _description;
        newCampaign.fundingGoal = _fundingGoal;
        newCampaign.deadline = block.timestamp + (_durationInDays * 1 days);
        newCampaign.totalFunds = 0;
        newCampaign.goalReached = false;
        newCampaign.fundsClaimed = false;

        campaignCount++;
        
        emit CampaignCreated(campaignId, msg.sender, _title, _fundingGoal, newCampaign.deadline);
    }

    /**
     * @dev Contribute funds to a campaign
     * @param _campaignId ID of the campaign to fund
     */
    function contribute(uint256 _campaignId) external payable {
        Campaign storage campaign = campaigns[_campaignId];
        
        require(msg.value > 0, "Contribution must be greater than 0");
        require(block.timestamp < campaign.deadline, "Campaign has ended");
        require(!campaign.fundsClaimed, "Funds have already been claimed");
        
        campaign.contributions[msg.sender] += msg.value;
        campaign.totalFunds += msg.value;
        
        if (campaign.totalFunds >= campaign.fundingGoal) {
            campaign.goalReached = true;
        }
        
        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }

    /**
     * @dev Campaign owner claims funds after successful campaign
     * @param _campaignId ID of the campaign
     */
    function claimFunds(uint256 _campaignId) external {
        Campaign storage campaign = campaigns[_campaignId];
        
        require(msg.sender == campaign.owner, "Only campaign owner can claim funds");
        require(campaign.goalReached, "Funding goal not reached");
        require(!campaign.fundsClaimed, "Funds have already been claimed");
        require(block.timestamp >= campaign.deadline, "Campaign is still active");
        
        campaign.fundsClaimed = true;
        
        uint256 fee = (campaign.totalFunds * platformFee) / 100;
        uint256 amountToTransfer = campaign.totalFunds - fee;
        
        (bool success, ) = campaign.owner.call{value: amountToTransfer}("");
        require(success, "Transfer failed");
        
        emit FundsClaimed(_campaignId, campaign.owner, amountToTransfer);
    }

    /**
     * @dev Contributors can claim refund if campaign fails
     * @param _campaignId ID of the campaign
     */
    function claimRefund(uint256 _campaignId) external {
        Campaign storage campaign = campaigns[_campaignId];
        
        require(block.timestamp >= campaign.deadline, "Campaign is still active");
        require(!campaign.goalReached, "Funding goal was reached");
        require(!campaign.fundsClaimed, "Funds have already been claimed");
        require(campaign.contributions[msg.sender] > 0, "No contribution found");
        
        uint256 contributionAmount = campaign.contributions[msg.sender];
        campaign.contributions[msg.sender] = 0;
        
        (bool success, ) = msg.sender.call{value: contributionAmount}("");
        require(success, "Transfer failed");
        
        emit RefundClaimed(_campaignId, msg.sender, contributionAmount);
    }

    
    function getCampaignDetails(uint256 _campaignId) external view returns (
        address owner,
        string memory title,
        string memory description,
        uint256 fundingGoal,
        uint256 deadline,
        uint256 totalFunds,
        bool goalReached,
        bool fundsClaimed
    ) {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.owner,
            campaign.title,
            campaign.description,
            campaign.fundingGoal,
            campaign.deadline,
            campaign.totalFunds,
            campaign.goalReached,
            campaign.fundsClaimed
        );
    }
}
