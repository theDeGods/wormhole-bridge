// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IRegistry} from '../modules/registry/IRegistry.sol';

contract MockRegistry is IRegistry {
	constructor() {}

	function isAllowedOperator(address operator) external view override returns (bool) {}

	function isAllowed(address operator) external view override returns (bool) {}

	function isBlocked(address operator) external view override returns (bool) {}
}