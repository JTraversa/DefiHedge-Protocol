pragma solidity ^0.5.9;

import "./safeMath.sol";

contract Erc20 {
  function approve(address, uint) external returns (bool);
  function transfer(address, uint) external returns (bool);
  function balanceOf(address _owner) external returns (uint256 balance);
  function transferFrom(address sender, address recipient, uint256 amount) public returns (bool);
}

contract CErc20 is Erc20 {
  function mint(uint) external returns (uint);
  function redeem(uint redeemTokens) external returns (uint);
  function redeemUnderlying(uint redeemAmount) external returns (uint);
  function exchangeRateCurrent() external returns (uint);
}

contract CEth {
  function mint() external payable;
  function redeem(uint redeemTokens) external returns (uint);
  function balanceOf(address _owner) external returns (uint256 balance);
  function approve(address spender, uint tokens) public returns (bool success);
  function redeemUnderlying(uint redeemAmount) external returns (uint);
  function exchangeRateCurrent() external returns (uint);
}

contract DefiHedge {
	
	struct RPCSig{
        uint8 v;
        bytes32 r;
        bytes32 s;
    }
    
    struct EIP712Domain {
        string  name;
        string  version;
        uint256 chainId;
        address verifyingContract;
    }
	
	struct OnChainOffer {
    	address maker;
        address taker;
        uint256 side;
        address tokenAddress;
        uint256 duration;
        uint256 rate;
        uint256 interest;
        uint256 base;
        uint256 state;
    }
	
	struct Offer {
    	address maker;
        address taker;
        uint256 side;
        address tokenAddress;
        uint256 duration;
        uint256 rate;
        uint256 interest;
        uint256 base;
    }
    
    struct signedOffer {
    	address maker;
        address taker;
        uint256 side;
        address tokenAddress;
        uint256 duration;
        uint256 rate;
        uint256 interest;
        uint256 base;
        uint256 state;
        uint256 lockTime;
        uint256 initialRate;
    }

    mapping (bytes32 => signedOffer) offerMapping;
    
    mapping (bytes32 => OnChainOffer) onChainOfferMapping;
    
    bytes32[] public onChainOfferList;
    
	bytes32[] public offerList;
	
    event newFixedOffer(
        bytes32 offerKey,
        address maker,
        address taker,
        address tokenAddress,
        uint256 duration,
        uint256 rate,
        uint256 interest,
        uint256 base
    );
    
    event newFloatingOffer(
        bytes32 offerKey,
        address maker,
        address taker,
        address tokenAddress,
        uint256 duration,
        uint256 rate,
        uint256 interest,
        uint256 base
    );
    
    event newLockedOffer(
        bytes32 offerKey,
        address maker,
        address taker,
        uint256 side,
        address tokenAddress,
        uint256 duration,
        uint256 rate,
        uint256 interest,
        uint256 base
    );
    
    event Aborted(
        bytes32 offerKey
        );
        
    event bondReleased(
        bytes32 offerKey
        );
    

    using SafeMath for uint;

	constructor () public {
        DOMAIN_SEPARATOR = hashDomain(EIP712Domain({
            name: "DefiHedge",
            version: '1',
            chainId: 3,
            verifyingContract: 0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC
        }));
    }
    
    bytes32 DOMAIN_SEPARATOR;
    
    // Offer + EIP Domain Hash Schema
    bytes32 constant EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 constant OFFER_TYPEHASH = keccak256(
        "Offer(address maker,address taker,uint256 side,address tokenAddress,uint256 duration,uint256 rate,uint256 interest,uint256 base)"
    );
    
    function hashDomain(EIP712Domain memory eip712Domain) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            EIP712DOMAIN_TYPEHASH,
            keccak256(bytes(eip712Domain.name)),
            keccak256(bytes(eip712Domain.version)),
            eip712Domain.chainId,
            eip712Domain.verifyingContract
        ));
    }
    
    function hashOffer(Offer memory _offer)private pure returns(bytes32){
        return keccak256(abi.encode(
            OFFER_TYPEHASH,
            _offer.maker,
            _offer.taker,
            _offer.side,
            _offer.tokenAddress,
            _offer.duration,
            _offer.rate,
            _offer.interest,
            _offer.base
        ));
    }
    
    
    function getOnChainOffer(bytes32 offerKey)
    public
    view
    returns (address maker, address taker, uint256 side, address tokenAddress, uint256 duration, uint256 rate, uint256 base, uint256 interest, uint256 state)
    {
        // Returns all offer details   
        maker = onChainOfferMapping[offerKey].maker;
        taker = onChainOfferMapping[offerKey].taker;
        side = onChainOfferMapping[offerKey].side;
        tokenAddress = onChainOfferMapping[offerKey].tokenAddress;
        duration = onChainOfferMapping[offerKey].duration;
        rate = onChainOfferMapping[offerKey].rate;
        interest = onChainOfferMapping[offerKey].interest;
        base = onChainOfferMapping[offerKey].base;
        state = onChainOfferMapping[offerKey].state;
        
        return (maker, taker, side, tokenAddress, duration, rate, base, interest, state);
    }
    
    function getActiveOffer(bytes32 offerKey)
    public
    view
    returns (address maker, address taker, uint256 side, address tokenAddress, uint256 duration, uint256 rate, uint256 base, uint256 interest, uint256 state, uint256 lockTime, uint256 initialRate)
    {
        // Returns all offer details
        maker = offerMapping[offerKey].maker;
        taker = offerMapping[offerKey].taker;
        side = offerMapping[offerKey].side;
        tokenAddress = offerMapping[offerKey].tokenAddress;
        duration = offerMapping[offerKey].duration;
        rate = offerMapping[offerKey].rate;
        interest = offerMapping[offerKey].interest;
        base = offerMapping[offerKey].base;
        state = offerMapping[offerKey].state;
        lockTime = offerMapping[offerKey].lockTime;
        initialRate = offerMapping[offerKey].initialRate;
        
        return (maker, taker, side, tokenAddress, duration, rate, base, interest, state, lockTime, initialRate);
    }
    
	// Deploy a new Erc lending contract
	function createOnChainErcOffer(address maker, address taker, uint side, address tokenAddress, uint256 duration, uint256 rate, uint256 interest, uint256 base)
	public
	returns (bytes32 _offerKey)
	{
	    
	    
	    Erc20 underlying = Erc20(tokenAddress);
	    
	    // Create unique offer key
	    bytes32 offerKey = keccak256(abi.encodePacked((now),msg.sender));
	    
	    // Require transfer of input erc amount
	    if (side == 0) {
	     	    require(underlying.transferFrom(maker, address(this), base), "Transfer Failed");
	     	    
	     	    emit newFixedOffer(offerKey, maker, taker, tokenAddress, rate, duration, interest, base);
	     	    
	    }
	    
	    if (side == 1) {
	        	require(underlying.transferFrom(maker, address(this), interest), "Transfer Failed");
	        	
	     	    emit newFloatingOffer(offerKey, maker, taker, tokenAddress, rate, duration, interest, base);
	    }
	    
	    // Save offer on-chain
	    OnChainOffer memory ercContract = onChainOfferMapping[offerKey];
	    
	    ercContract.maker = address(msg.sender);
	    ercContract.taker = taker;
	    ercContract.side = side;
	    ercContract.tokenAddress = tokenAddress;
	    ercContract.duration = duration;
	    ercContract.rate = rate;
	    ercContract.interest = interest;
	    ercContract.base = base;
	    ercContract.state = 0;
	    
	    onChainOfferList.push(offerKey) -1;
	    
	    return offerKey;
	}
	
	
	// Deploy a new Eth lending contract
	function createOnChainEthOffer(address maker, address taker, uint side, address tokenAddress, uint256 duration, uint256 rate, uint256 interest, uint256 base)
	public
	payable
	returns (bytes32 _offerKey)
	{
	    
	    // Create unique offer key
	    bytes32 offerKey = keccak256(abi.encodePacked((now),msg.sender));
	    
	    if (side == 0) {
	        
	        // Require correct value between transaction and input value
	        require(base == msg.value, "Invalid Transaction/Input Value");
	        
	        // Save offer on-chain
	        OnChainOffer memory ethOffer = OnChainOffer(
	                                                 msg.sender,
	                                                 taker,
	                                                 side,
	                                                 tokenAddress,
	                                                 duration,
	                                                 rate,
	                                                 interest,
	                                                 msg.value,
	                                                 0
	                                                 );
	    
    	    onChainOfferMapping[offerKey] = ethOffer;
    	    
    	    onChainOfferList.push(offerKey);
    	    
    	    emit newFixedOffer(offerKey, maker, taker, tokenAddress, rate, duration, interest, msg.value);
    	    
    	    return(offerKey);
    	   
	     	    
	    }
	    if (side == 1) {
	        
	        require(interest == msg.value, "Invalid Transaction/Input Value");
	        
	        OnChainOffer memory ethOffer = OnChainOffer(
	                                                 msg.sender,
	                                                 taker,
	                                                 side,
	                                                 tokenAddress,
	                                                 duration,
	                                                 rate,
	                                                 msg.value,
	                                                 base,
	                                                 0
	                                                 );
	    
    	    onChainOfferMapping[offerKey] = ethOffer;
    	    
    	    onChainOfferList.push(offerKey);
    	   
    	   	emit newFloatingOffer(offerKey, maker, taker, tokenAddress, rate, duration, msg.value, base); 
    	   	
    	    return(offerKey);
    	   
	    }
	    
	    
	}
	
	function takeEthOffer(bytes32 offerKey) public payable returns (bytes32){
	    
	    // Require offer to be in state "created"
	    require (onChainOfferMapping[offerKey].state == 0, "Invalid State");
	    
	    // Transfer taker funds to contract	    
	    if (onChainOfferMapping[offerKey].side == 0){
	           require(msg.value >= onChainOfferMapping[offerKey].interest, "Transfer Failed");
	    }
	    if (onChainOfferMapping[offerKey].side == 1){
	           require(msg.value >= onChainOfferMapping[offerKey].base, "Transfer Failed");
	    }
	    
	    // Mint Ctokens	    
	    mintCEther((onChainOfferMapping[offerKey].base).add((onChainOfferMapping[offerKey].interest)));
	    
	    // Set taker address	    
	    onChainOfferMapping[offerKey].taker = msg.sender;
	    
	    // Set state to Active
	    onChainOfferMapping[offerKey].state = 1;
	    
	    // Set locktime	    
	    offerMapping[offerKey].lockTime = onChainOfferMapping[offerKey].duration.add(now);
	   
	    emit newLockedOffer(offerKey,onChainOfferMapping[offerKey].maker,onChainOfferMapping[offerKey].taker,onChainOfferMapping[offerKey].side,onChainOfferMapping[offerKey].tokenAddress,onChainOfferMapping[offerKey].duration,onChainOfferMapping[offerKey].rate,onChainOfferMapping[offerKey].interest,onChainOfferMapping[offerKey].base);
	}
	
	function takeErcOffer(bytes32 offerKey) public payable returns (bytes32){
	    
	    // Require offer to be in state "created"
	    require (onChainOfferMapping[offerKey].state == 0, "Invalid State");
	    
	    Erc20 underlying = Erc20(onChainOfferMapping[offerKey].tokenAddress);
	    
	    // Transfer taker funds to contract
	    if (onChainOfferMapping[offerKey].side == 0){
	           require(underlying.transferFrom(msg.sender, address(this), onChainOfferMapping[offerKey].interest), "Transfer Failed");
	           
	    }
	    if (onChainOfferMapping[offerKey].side == 1){
	           require(underlying.transferFrom(msg.sender, address(this), onChainOfferMapping[offerKey].base), "Transfer Failed");
	    }
	    
	    // Mint Ctokens
	    mintCToken(onChainOfferMapping[offerKey].tokenAddress,(onChainOfferMapping[offerKey].base).add((onChainOfferMapping[offerKey].interest)));
	    
	    // Set taker address
	    onChainOfferMapping[offerKey].taker = msg.sender;
	    
	    // Set state to Active
	    onChainOfferMapping[offerKey].state = 1;
	    
	    // Set locktime
	    offerMapping[offerKey].lockTime = onChainOfferMapping[offerKey].duration.add(now);
	   
	    emit newLockedOffer(offerKey,onChainOfferMapping[offerKey].maker,onChainOfferMapping[offerKey].taker,onChainOfferMapping[offerKey].side,onChainOfferMapping[offerKey].tokenAddress,onChainOfferMapping[offerKey].duration,onChainOfferMapping[offerKey].rate,onChainOfferMapping[offerKey].interest,onChainOfferMapping[offerKey].base);
	}
	
	
	function offerSettle(address maker, address taker, uint256 side, address tokenAddress, uint256 duration, uint256 interest, uint256 base, uint256 value, bytes32 offerKey) private returns (uint256){
	    

	    
	    signedOffer memory currentOffer;
	    
	    CErc20 cToken = CErc20(0xdb5Ed4605C11822811a39F94314fDb8F0fb59A2C); //DAI cToken Address

	        // Check trades side
	        // Transfers funds to DefiHedge contract
    	    Erc20 underlying = Erc20(tokenAddress);
    	    if (side == 0) {
	        require(underlying.transferFrom(maker, address(this), base), "Transfer Failed!");
            require(underlying.transferFrom(taker, address(this), interest), "Transfer Failed!");
    	    }
    	    if (side == 1) {
	        require(underlying.transferFrom(maker, address(this), interest), "Transfer Failed!");
            require(underlying.transferFrom(taker, address(this), base), "Transfer Failed!");
    	    }
    	    
    	    // Mint CToken from DefiHedge contract
            uint mintResponse = mintCToken(tokenAddress,value);
            
            // Set locktime uint + set state to active
            uint lockTime = now.add(duration);
    	    
    	    uint state = 1;
    	    
    	    // Set variables for the offer on-chain
    	    currentOffer.maker = maker;
    	    currentOffer.taker = taker;
    	    currentOffer.side = side;
    	    currentOffer.tokenAddress = tokenAddress;
    	    currentOffer.duration = duration;
    	    currentOffer.rate = 0;
    	    currentOffer.interest = interest;
    	    currentOffer.base = base;
    	    currentOffer.state = state;
    	    currentOffer.lockTime = lockTime;
    	    currentOffer.initialRate = cToken.exchangeRateCurrent();
    	    
    	    offerMapping[offerKey] = currentOffer;
    	    
    	    return mintResponse;
	    
	    
	}
	
	function fillOffer(address maker, address taker, uint side, address tokenAddress, uint duration, uint rate, uint interest, uint base, bytes memory makerSignature) public returns (uint256){
	    
	    /// Instantiate offer
	    Offer memory filledOffer = Offer(
	                                                     maker,
	                                                     address(0x0000000000000000000000000000000000000000),
	                                                     side,
	                                                     tokenAddress,
	                                                     duration,
	                                                     rate,
	                                                     interest,
	                                                     base
	                                                     );
	                                                     
	     // Parse signature into R,S,V                        
	    RPCSig memory RPCsig = signatureRPC(makerSignature);
	    
	     // Validate offer signature & ensure it was created by maker
	    require(maker == ecrecover(
	        keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            hashOffer(filledOffer)
            )),
            RPCsig.v,
            RPCsig.r,
            RPCsig.s), "Invalid Signature");
            
        // Require correct taker
	    require(msg.sender == taker, "Invalid Calling Address");
        
	     // Create unique offer hash
	    bytes32 offerKey = keccak256(abi.encodePacked((now),msg.sender));
	     
	    uint value = interest.add(base);
	        
	    // Settle Response
	    offerSettle(maker,taker,side,tokenAddress,duration,interest,base,value,offerKey);
	    
	    offerMapping[offerKey].rate = rate;
	    
	    offerList.push(offerKey);
	    
	    emit newLockedOffer(offerKey,maker,taker,side,tokenAddress,duration,rate,interest,base);
        
	    
	}
	
	 /// Abort an offer
	function abort(bytes32 offerKey) public
	{
	    Erc20 underlying = Erc20(onChainOfferMapping[offerKey].tokenAddress);
	    require(msg.sender == onChainOfferMapping[offerKey].maker, "Invalid Calling Address");
	    require(onChainOfferMapping[offerKey].state == 0, "Invalid State");
		
		/// Return funds to maker
		if (onChainOfferMapping[offerKey].side == 1) {
		    
		require(underlying.transfer(onChainOfferMapping[offerKey].maker, onChainOfferMapping[offerKey].interest));    
		
		onChainOfferMapping[offerKey].state = 2;
		
		}
		
		if (onChainOfferMapping[offerKey].side == 0) {
		    
		require(underlying.transfer(onChainOfferMapping[offerKey].maker, onChainOfferMapping[offerKey].base));    
		
		onChainOfferMapping[offerKey].state = 2;
		
		}
		
		emit Aborted(offerKey);
	}
	
	 /// Release an Erc bond once if term completed
	function releaseErcBond(bytes32 offerKey)
	public
	returns(uint256)
	{

        
        // Require swap state to be active
        // Require swap duration to have expired
        require(offerMapping[offerKey].state == 1, "Invalid State");
		require(now >= offerMapping[offerKey].lockTime, "Invalid Time");
		
	    CErc20 CDai = CErc20(0xdb5Ed4605C11822811a39F94314fDb8F0fb59A2C);
	    Erc20 underlying = Erc20(offerMapping[offerKey].tokenAddress);
	    
	    // Calculate annualized interest-rate generated by the swap agreement
		uint total = offerMapping[offerKey].base.add(offerMapping[offerKey].interest);
		uint rate = CDai.exchangeRateCurrent();
		uint yield = ((rate.mul(100000000000000000000000000)).div(offerMapping[offerKey].initialRate)).sub(100000000000000000000000000);
		uint annualizedRate = ((yield.mul(31536000)).div(offerMapping[offerKey].duration));

		// In order to avoid subtraction underflow, ensures subtraction of smaller annualized rate
		if (offerMapping[offerKey].rate > annualizedRate) {
		    
		    // Calculates difference between annualized expected rate / real rate 
    	    uint rateDifference = (offerMapping[offerKey].rate).sub(annualizedRate);
    	    
    	    // Calculates differential in expected currency from previous rate differential
    	    uint annualFloatingDifference = (rateDifference.mul(total)).div(100000000000000000000000000);
    	    
    	 	// De-annualizes the differential for the given time period
    	    uint floatingDifference = (annualFloatingDifference.div(31536000)).mul(offerMapping[offerKey].duration);
    	    
    	    // Calculates difference between value and expected interest
            uint floatingReturned = (offerMapping[offerKey].interest).sub(floatingDifference);
            
            // Redeems appropriate CTokens
		    redeemCToken(0xdb5Ed4605C11822811a39F94314fDb8F0fb59A2C,(total.add(floatingReturned)));
		    
		    // Returns funds to appropriate parties
            if (offerMapping[offerKey].side == 0){
    		    underlying.transfer(offerMapping[offerKey].maker, total);
    		    underlying.transfer(offerMapping[offerKey].taker, floatingReturned);
		}
		    if (offerMapping[offerKey].side == 1){
    		    underlying.transfer(offerMapping[offerKey].maker, floatingReturned);
    		    underlying.transfer(offerMapping[offerKey].taker, total);
		}
		}
		
		if (annualizedRate > offerMapping[offerKey].rate) {
    	    uint rateDifference = annualizedRate.sub(offerMapping[offerKey].rate);
    	    uint annualFloatingDifference = (rateDifference.mul(total)).div(100000000000000000000000000);
    	    uint floatingDifference = (annualFloatingDifference.div(31536000)).mul(offerMapping[offerKey].duration);
            uint floatingReturned = (offerMapping[offerKey].interest).add(floatingDifference);

    	    redeemCToken(0xdb5Ed4605C11822811a39F94314fDb8F0fb59A2C,(total.add(floatingReturned)));
    	    
            if (offerMapping[offerKey].side == 0){
    		    underlying.transfer(offerMapping[offerKey].maker, total);
    		    underlying.transfer(offerMapping[offerKey].taker, floatingReturned);
		}
		    if (offerMapping[offerKey].side == 1){
    		    underlying.transfer(offerMapping[offerKey].maker, floatingReturned);
    		    underlying.transfer(offerMapping[offerKey].taker, total);
		}
		}
		
		if (annualizedRate == offerMapping[offerKey].rate) {
		    
		    redeemCToken(0xdb5Ed4605C11822811a39F94314fDb8F0fb59A2C,(total.add(offerMapping[offerKey].interest)));
		    
            if (offerMapping[offerKey].side == 0){
    		    underlying.transfer(offerMapping[offerKey].maker, total);
    		    underlying.transfer(offerMapping[offerKey].taker, offerMapping[offerKey].interest);
		}
		    if (offerMapping[offerKey].side == 1){
    		    underlying.transfer(offerMapping[offerKey].maker, offerMapping[offerKey].interest);
    		    underlying.transfer(offerMapping[offerKey].taker, total);
		}
		}
		
		// Change state to Expired
		offerMapping[offerKey].state = 2;
		
    	emit bondReleased(offerKey);

		
		return(offerMapping[offerKey].state);
		
		
	}
	
	function releaseEthBond(bytes32 offerKey)
	public
	{
	    
        // Require swap state to be active
        // Require swap duration to have expired
        require(offerMapping[offerKey].state == 1, "Invalid State");
		require(now >= offerMapping[offerKey].lockTime, "Invalid Time");
		
	    CEth cEth = CEth(0xBe839b6D93E3eA47eFFcCA1F27841C917a8794f3);
	    
	    // Calculate annualized interest-rate generated by the swap agreement
		uint total = offerMapping[offerKey].base.add(offerMapping[offerKey].interest);
		uint rate = cEth.exchangeRateCurrent();
		uint yield = ((rate.mul(100000000000000000000000000)).div(offerMapping[offerKey].initialRate)).sub(100000000000000000000000000);
		uint annualizedRate = ((yield.mul(31536000)).div(offerMapping[offerKey].duration));

		// In order to avoid subtraction underflow, ensures subtraction of smaller annualized rate
		if (offerMapping[offerKey].rate > annualizedRate) {
		    
		    // Calculates difference between annualized expected rate / real rate 
    	    uint rateDifference = (offerMapping[offerKey].rate).sub(annualizedRate);
    	    
    	    // Calculates differential in expected currency from previous rate differential
    	    uint annualFloatingDifference = (rateDifference.mul(total)).div(100000000000000000000000000);
    	    
    	    // De-annualizes the differential for the given time period
    	    uint floatingDifference = (annualFloatingDifference.div(31536000)).mul(offerMapping[offerKey].duration);
    	    
    	    // Calculates difference between value and expected interest
            uint floatingReturned = (offerMapping[offerKey].interest).sub(floatingDifference);


            // Redeems appropriate CEther
		    redeemCEther(total.add(floatingReturned));
		    
		    // Returns funds to appropriate parties
            if (offerMapping[offerKey].side == 0){
                address payable returnMaker = address(uint160(offerMapping[offerKey].maker));
                address payable returnTaker = address(uint160(offerMapping[offerKey].taker));
    		    returnMaker.transfer(total);
    	        returnTaker.transfer(floatingReturned);
		}
		    if (offerMapping[offerKey].side == 1){
		        address payable returnMaker = address(uint160(offerMapping[offerKey].maker));
                address payable returnTaker = address(uint160(offerMapping[offerKey].taker));
    		    returnMaker.transfer(floatingReturned);
    	        returnTaker.transfer(total);
		}
		}
		
		if (annualizedRate > offerMapping[offerKey].rate) {
    	    uint rateDifference = annualizedRate.sub(offerMapping[offerKey].rate);
    	    uint annualFloatingDifference = (rateDifference.mul(total)).div(100000000000000000000000000);
    	    uint floatingDifference = (annualFloatingDifference.div(31536000)).mul(offerMapping[offerKey].duration);
            uint floatingReturned = (offerMapping[offerKey].interest).add(floatingDifference);

    	    redeemCEther(total.add(floatingReturned));
    	    
            if (offerMapping[offerKey].side == 0){
                address payable returnMaker = address(uint160(offerMapping[offerKey].maker));
                address payable returnTaker = address(uint160(offerMapping[offerKey].taker));
    		    returnMaker.transfer(total);
    	        returnTaker.transfer(floatingReturned);
		}
		    if (offerMapping[offerKey].side == 1){
		        address payable returnMaker = address(uint160(offerMapping[offerKey].maker));
                address payable returnTaker = address(uint160(offerMapping[offerKey].taker));
    		    returnMaker.transfer(floatingReturned);
    	        returnTaker.transfer(total);
		}
		}
		
		if (annualizedRate == offerMapping[offerKey].rate) {
		    
		    redeemCEther(total.add(offerMapping[offerKey].interest));
		    
            if (offerMapping[offerKey].side == 0){
                address payable returnMaker = address(uint160(offerMapping[offerKey].maker));
                address payable returnTaker = address(uint160(offerMapping[offerKey].taker));
    		    returnMaker.transfer(total);
    	        returnTaker.transfer(offerMapping[offerKey].interest);
		}
		    if (offerMapping[offerKey].side == 1){
		        address payable returnMaker = address(uint160(offerMapping[offerKey].maker));
                address payable returnTaker = address(uint160(offerMapping[offerKey].taker));
    		    returnMaker.transfer(offerMapping[offerKey].interest);
    	        returnTaker.transfer(total);
		}
		}
		
		
    	emit bondReleased(offerKey);

	    
		
	}
	
		/// Mint Cether
	function mintCEther(uint value) internal returns (uint response){
	    
	    address CEthAdress = 0x1d70B01A2C3e3B2e56FcdcEfe50d5c5d70109a5D;
	    CEth cEth = CEth(CEthAdress);
	    
	    cEth.mint.value((value))();
	    
	    return response;
	    
	}
	    /// Redeem Cether
	function redeemCEther(uint value) internal {
	    address CEthAdress = 0x1d70B01A2C3e3B2e56FcdcEfe50d5c5d70109a5D;
	    CEth cEth = CEth(CEthAdress);
	    cEth.redeemUnderlying(value);
	}
	
		/// Mint cToken
	function mintCToken(
      address _erc20Contract,
      uint _numTokensToSupply
    ) internal returns (uint) {
        
      Erc20 underlying = Erc20(_erc20Contract);

      CErc20 cToken = CErc20(0xdb5Ed4605C11822811a39F94314fDb8F0fb59A2C);
      
      // Approve transfer on the ERC20 contract
      underlying.approve(0xdb5Ed4605C11822811a39F94314fDb8F0fb59A2C, _numTokensToSupply);
      
      
      uint mintResult = cToken.mint(_numTokensToSupply);
      
      return mintResult;
    }
    	    
	    /// Redeem cToken
	function redeemCToken(
        address _cErc20Contract, uint _numTokensToRedeem) internal {
        CErc20(_cErc20Contract).redeemUnderlying(_numTokensToRedeem);
	}
	
	// Splits signature into RSV
	function signatureRPC(bytes memory sig)internal pure returns (RPCSig memory RPCsig){
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        if (sig.length != 65) {
          return RPCSig(0,'0','0');
        }
    
        assembly {
          r := mload(add(sig, 32))
          s := mload(add(sig, 64))
          v := and(mload(add(sig, 65)), 255)
        }
        
        if (v < 27) {
          v += 27;
        }
                
        if (v == 39 || v == 40) {
          v = v-12;
        }
        
        if (v != 27 && v != 28) {
          return RPCSig(0,'0','0');
        }
        
        return RPCSig(v,r,s);
    }

}

