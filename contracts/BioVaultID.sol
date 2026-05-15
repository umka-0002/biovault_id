// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BioVaultID {
    mapping(address => string) public faceSyndrome;
    mapping(address => string) public ipfsCID;
    mapping(address => uint256) public lastVerificationTime;
    mapping(address => uint256) public verificationCount;

    event BioRegistered(address indexed user, string syndrome, string ipfsCID);
    event VerificationSuccess(address indexed user, uint256 timestamp);

    function registerBio(string calldata _syndrome, string calldata _ipfsCID) external {
        require(bytes(faceSyndrome[msg.sender]).length == 0, "Already registered");
        faceSyndrome[msg.sender] = _syndrome;
        ipfsCID[msg.sender] = _ipfsCID;
        lastVerificationTime[msg.sender] = block.timestamp;
        verificationCount[msg.sender] = 0;
        emit BioRegistered(msg.sender, _syndrome, _ipfsCID);
    }

    function verifyBio(string calldata _providedSyndrome) external {
        require(bytes(faceSyndrome[msg.sender]).length != 0, "Not registered");
        require(
            keccak256(bytes(faceSyndrome[msg.sender])) == keccak256(bytes(_providedSyndrome)),
            "Verification failed"
        );
        lastVerificationTime[msg.sender] = block.timestamp;
        verificationCount[msg.sender] += 1;
        emit VerificationSuccess(msg.sender, block.timestamp);
    }

    function getUserData(address _user)
        external
        view
        returns (
            string memory syndrome,
            string memory ipfs,
            uint256 lastVerification,
            uint256 totalVerifications
        )
    {
        return (
            faceSyndrome[_user],
            ipfsCID[_user],
            lastVerificationTime[_user],
            verificationCount[_user]
        );
    }
}
