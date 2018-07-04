/* Copyright (C) 2017 GovBlocks.io

  This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

  This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
    along with this program.  If not, see http://www.gnu.org/licenses/ */
//TODO fix activeVersion

pragma solidity ^ 0.4.8;

import "./Upgradeable.sol";
import "./GBTStandardToken.sol";
import "./GovBlocksMaster.sol";
import "./Ownable.sol";
import "./GovernanceData.sol";


contract Master is Ownable, Upgradeable {

    struct ChangeVersion {
        uint dateImplement;
        uint16 versionNo;
    }

    uint16 public versionLength;
    bytes32 public dAppName;
    bytes2[] private allContractNames;
    ChangeVersion[] public contractChangeDate;
    mapping(address => bool) public contractsActive;
    mapping(uint16 => mapping(bytes2 => address)) public allContractVersions;

    GovBlocksMaster private gbm;
    Upgradeable private up;
    bool public constructorCheck;
    address public gbmAddress;

    /// @dev Constructor function for master
    /// @param _govBlocksMasterAddress GovBlocks master address
    /// @param _gbUserName dApp Name which is integrating GovBlocks.
    function Master(address _govBlocksMasterAddress, bytes32 _gbUserName) {
        contractsActive[address(this)] = true;
        versionLength = 0;
        gbmAddress = _govBlocksMasterAddress;
        dAppName = _gbUserName;
        owner = msg.sender;
        addContractNames();
    }

    modifier onlyOwner {
        require(isOwner(msg.sender));
        _;
    }

    modifier onlyAuthorizedGB {
        gbm = GovBlocksMaster(gbmAddress);
        require(gbm.isAuthorizedGBOwner(dAppName, msg.sender));
        _;
    }

    modifier onlyInternal {
        require(contractsActive[msg.sender] || owner == msg.sender);
        _;
    }

    /// @dev Returns true if the caller address is GovBlocksMaster Address.
    function isGBM(address _gbmAddress) public constant returns(bool check) {
        require(_gbmAddress == gbmAddress);
        check = true;
    }

    /// @dev Checks for authorized Member for Dapp and returns true if the address is authorized in dApp.
    /// @param _memberaddress Address to be checked
    function isAuthGB(address _memberaddress) public constant returns(bool check) {
        gbm = GovBlocksMaster(gbmAddress);
        require(gbm.isAuthorizedGBOwner(dAppName, _memberaddress));
        check = true;
    }

    /// @dev Checks if the caller address is either one of its active contract address or owner.
    /// @param _address  address to be checked for internal
    /// @return check returns true if the condition meets
    function isInternal(address _address) public constant returns(bool check) {
        if (contractsActive[_address] || owner == _address)
            check = true;
    }

    /// @dev Checks if the caller address is owner
    /// @param _ownerAddress member address to be checked for owner
    /// @return check returns true if the address is owner address
    function isOwner(address _ownerAddress) public constant returns(bool check) {
        if (owner == _ownerAddress)
            check = true;
    }

    /// @dev Sets owner 
    /// @param _memberaddress Contract address to be set as owner
    function setOwner(address _memberaddress) public onlyOwner {
        owner = _memberaddress;
    }

    /// @dev Creates a new version of contract addresses
    /// @param _contractAddresses Array of nine contract addresses which will be generated
    function addNewVersion(address[6] _contractAddresses) public onlyAuthorizedGB {
        gbm = GovBlocksMaster(gbmAddress);
        addContractDetails(versionLength, "MS", address(this));
        addContractDetails(versionLength, "GD", _contractAddresses[0]);
        addContractDetails(versionLength, "MR", _contractAddresses[1]);
        addContractDetails(versionLength, "PC", _contractAddresses[2]);
        addContractDetails(versionLength, "SV", _contractAddresses[3]);
        //addContractDetails(versionLength, "VT", _contractAddresses[4]);
        addContractDetails(versionLength, "GV", _contractAddresses[4]);
        addContractDetails(versionLength, "PL", _contractAddresses[5]);
        addContractDetails(versionLength, "GS", gbm.getGBTAddress());
        setVersionLength(versionLength + 1);
    }

    /// @dev Switches to the recent version of contracts
    function switchToRecentVersion() public {
        require(isValidateOwner());
        addInContractChangeDate();
        changeAllAddress();
    }

    /// @dev just for the interface
    function updateDependencyAddresses() public onlyInternal {
    }

    /// @dev just for the interface
    function changeGBTSAddress(address _gbtAddress) public onlyInternal {
        require(isValidateOwner());
        for (uint8 i = 1; i < allContractNames.length - 1; i++) {
            up = Upgradeable(allContractVersions[versionLength - 1][allContractNames[i]]);
            up.changeMasterAddress(address(this));
            up.changeGBTSAddress(_gbtAddress);
        }
    }

    /// @dev Changes Master contract address
    function changeMasterAddress(address _masterAddress) public onlyInternal {
        Master master = Master(_masterAddress);
        require(master.versionLength() > 0);
        addContractDetails(versionLength - 1, "MS", _masterAddress);
        for (uint8 i = 1; i < allContractNames.length - 1; i++) {
            up = Upgradeable(allContractVersions[versionLength - 1][allContractNames[i]]);
            up.changeMasterAddress(_masterAddress);
        }
        //GBM=GovBlocksMaster(GBMAddress);
        //GBM.changeDappMasterAddress(DappName,_MasterAddress);  Requires Auth Address
    }

    /// @dev Checks the authenticity of changing address or switching to recent version 
    function isValidateOwner() public constant returns(bool) {
        gbm = GovBlocksMaster(gbmAddress);
        uint16 version = versionLength - 1;
        if ((version == 0 && msg.sender == owner) 
                || msg.sender == gbmAddress 
                || gbm.isAuthorizedGBOwner(dAppName, msg.sender)) 
            return true;
    }

    /// @dev Changes GovBlocks Master address
    /// @param _gbmNewAddress New GovBlocks master address
    function changeGBMAddress(address _gbmNewAddress) public {
        require(msg.sender == gbmAddress);
        gbmAddress == _gbmNewAddress;
    }

    /// @dev Gets current version amd its master address
    /// @return versionNo Current version number that is active
    /// @return MSAddress Master contract address
    function getCurrentVersion() public constant returns(uint16 versionNo, address msAddress) {
        versionNo = contractChangeDate[contractChangeDate.length - 1].versionNo;
        msAddress = allContractVersions[versionNo]["MS"];
    }

    /// @dev Gets latest version name and address
    /// @param _versionNo Version number that data we want to fetch
    /// @return versionNo Version number
    /// @return contractsName Latest version's contract names
    /// @return contractsAddress Latest version's contract addresses
    function getLatestVersionData(uint16 _versionNo) 
        public 
        constant 
        returns(uint16 versionNo, bytes2[] contractsName, address[] contractsAddress) 
    {
        versionNo = _versionNo;
        contractsName = new bytes2[](allContractNames.length);
        contractsAddress = new address[](allContractNames.length);

        for (uint8 i = 0; i < allContractNames.length; i++) {
            contractsName[i] = allContractNames[i];
            contractsAddress[i] = allContractVersions[versionNo][allContractNames[i]];
        }
    }

    /// @dev Gets latest contract address
    /// @param _contractName Contract name to fetch
    function getLatestAddress(bytes2 _contractName) public constant returns(address contractAddress) {
        contractAddress = allContractVersions[contractChangeDate[contractChangeDate.length - 1].versionNo][_contractName];
    }

    /// @dev Save the initials of all the contracts
    function addContractNames() internal {
        allContractNames.push("MS");
        allContractNames.push("GD");
        allContractNames.push("MR");
        allContractNames.push("PC");
        allContractNames.push("SV");
        allContractNames.push("GV");
        allContractNames.push("PL");
        allContractNames.push("GS");
    }

    /// @dev Sets the length of version
    /// @param _length Length of the version
    function setVersionLength(uint16 _length) internal {
        versionLength = _length;
    }

    /// @dev Adds contract's name  and its address in a given version
    /// @param _versionNo Version number of the contracts
    /// @param _contractName Contract name
    /// @param _contractAddress Contract addresse
    function addContractDetails(uint16 _versionNo, bytes2 _contractName, address _contractAddress) internal {
        allContractVersions[_versionNo][_contractName] = _contractAddress;
    }

    /// @dev Deactivates address of a contract from last version
    /// @param _version Version of the new contracts
    /// @param _contractName Contract name
    function addRemoveAddress(uint16 _version, bytes2 _contractName) internal {
        uint16 versionOld;
        if (_version > 0)
            versionOld = contractChangeDate[contractChangeDate.length - 2].versionNo;
        contractsActive[allContractVersions[versionOld][_contractName]] = false;
        contractsActive[allContractVersions[_version][_contractName]] = true;
    }

    /// @dev Stores the date when version of contracts get switched
    function addInContractChangeDate() internal {
        contractChangeDate.push(ChangeVersion(now, versionLength - 1));
    }

    /// @dev Sets the older versions of contract addresses as inactive and the latest one as active.
    function changeAllAddress() internal {
        for (uint8 i = 0; i < allContractNames.length - 1; i++) {
            addRemoveAddress(versionLength - 1, allContractNames[i]);
            up = Upgradeable(allContractVersions[versionLength - 1][allContractNames[i]]);
            up.changeMasterAddress(address(this));
            up.updateDependencyAddresses();
        }
        addRemoveAddress(versionLength - 1, allContractNames[allContractNames.length - 1]);
    }

    /// @dev Configures global parameters i.e. Voting or Reputation parameters
    /// @param _typeOf Passing intials of the parameter name which value needs to be updated
    /// @param _value New value that needs to be updated    
    function configureGlobalParameters(bytes4 _typeOf, uint32 _value) public {
        require(msg.sender == 
            allContractVersions[contractChangeDate[contractChangeDate.length - 1].versionNo]["SV"]
        );
        GovernanceData governanceDat = GovernanceData(
                    allContractVersions[contractChangeDate[contractChangeDate.length - 1].versionNo]["GD"]
                );
        if (_typeOf == "APO") {
            governanceDat.changeProposalOwnerAdd(_value);
        } else if (_typeOf == "AOO") {
            governanceDat.changeSolutionOwnerAdd(_value);
        } else if (_typeOf == "AVM") {
            governanceDat.changeMemberAdd(_value);
        } else if (_typeOf == "SPO") {
            governanceDat.changeProposalOwnerSub(_value);
        } else if (_typeOf == "SOO") {
            governanceDat.changeSolutionOwnerSub(_value);
        } else if (_typeOf == "SVM") {
            governanceDat.changeMemberSub(_value);
        } else if (_typeOf == "GBTS") {
            governanceDat.changeGBTStakeValue(_value);
        } else if (_typeOf == "MSF") {
            governanceDat.changeMembershipScalingFator(_value);
        } else if (_typeOf == "SW") {
            governanceDat.changeScalingWeight(_value);
        } else if (_typeOf == "QP") {
            governanceDat.changeQuorumPercentage(_value);
        }
    }
}