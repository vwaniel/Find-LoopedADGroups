function Find-LoopedADGroups {
	#Requires -Modules ActiveDirectory
	[cmdletbinding()]
	param()

	$global:arrLoopedGroups = [System.Collections.ArrayList]@()
	$global:htGroupTracking = @{}

	# Functions
	function NewHTGroup {
		param(
			[Parameter(Mandatory=$true,Position=1)][string]$group,
			[Parameter(Mandatory=$false,Position=2)][string]$parent
		)
		$global:htGroupTracking.Add($group,$(New-Object PSObject -Property @{
			"Group" = $group;
			"DirectParents" = $null;
			"AllParents" = @{};
			"AllParentsArray" = $null;
			"DirectChildren" = $null;
			"AllChildren" = @{};
			"AllChildrenArray" = $null;
		})) > $null
		$global:htGroupTracking[$group].DirectParents = [System.Collections.ArrayList]@()
		$global:htGroupTracking[$group].DirectChildren = [System.Collections.ArrayList]@()
		$global:htGroupTracking[$group].AllParentsArray = [System.Collections.ArrayList]@()
		$global:htGroupTracking[$group].AllChildrenArray = [System.Collections.ArrayList]@()
		if ($parent) {
			$global:htGroupTracking[$group].DirectParents.Add($parent) > $null
		}
	}

	function NewLoopObject {
		param(
			[Parameter(Mandatory=$true,Position=1)][string]$group
		)
		$obj = New-Object PSObject -Property @{
			"StartingGroup" = $group;
			"LoopParticipants" = $null;
		}
		
		$obj.LoopParticipants = [System.Collections.ArrayList]@()
		$obj.LoopParticipants.Add($group) > $null
		
		return $obj
	}

	# Get all groups.
	$arrGroups = [System.Collections.ArrayList]@()
	Get-AdGroup -Filter * | Foreach-Object {$arrGroups.Add($_.DistinguishedName) > $null}

	foreach ($group in $arrGroups) {
		Write-Progress -Activity "Scanning For Looped Groups" -Status "$($group)" -PercentComplete ((($arrGroups.IndexOf($group)/$($arrGroups | Measure-Object).Count))*100)
		$arrGroupsToScan = [System.Collections.ArrayList]@()
		
		$arrGroupsToScan.Add($(New-Object PSObject -Property @{
			"Group" = $group;
			"Parent" = $null
		})) > $null
		
		# Discovery
		while ($arrGroupsToScan) {
			$scanningGroup = $arrGroupsToScan | Select -First 1
			if ($global:htGroupTracking.Keys -contains $scanningGroup.Group) {
				# Group has already been discovered.  Check parent status.
				if ($scanningGroup.Parent) {
					if ($global:htGroupTracking[$scanningGroup.Group].DirectParents -notcontains $scanningGroup.Parent) {
						$global:htGroupTracking[$scanningGroup.Group].DirectParents.Add($scanningGroup.Parent) > $null
					} else {
						# Child-parent relationship was already discovered, may be evidence of a loop.
						Write-Warning "Possible loop detected between $($scanningGroup.Group) and $($scanningGroup.Parent)"
					}
				} else {
					# Group was already discovered as a child of another group.
				}
			} else {
				NewHTGroup $scanningGroup.Group $scanningGroup.Parent
				# Discover the group's children.
				Get-AdGroup -Identity "$($scanningGroup.Group)" -Properties Member | Select-Object -Expand Member | Foreach-Object {Get-AdObject -Identity $_} | Where {$_.objectClass -eq "group"} | Foreach-Object {
					if ($global:htGroupTracking.Keys -contains $_.DistinguishedName) {
						# Group has already been discovered, do not need to discover again.
						if ($_.DistinguishedName -eq $scanningGroup.Group) {
							#Write-Host "Loop detected in $($group).  Parent $($group) is a member of $($scanningGroup.Group)."
						}
						if ($global:htGroupTracking[$_.DistinguishedName].DirectParents -notcontains $scanningGroup.Group) {
							$global:htGroupTracking[$_.DistinguishedName].DirectParents.Add($scanningGroup.Group) > $null
						}
					} else {
						$arrGroupsToScan.Add($(New-Object PSObject -Property @{
							"Group" = $_.DistinguishedName;
							"Parent" = $scanningGroup.Group;
						})) > $null
					}
					if ($global:htGroupTracking[$scanningGroup.Group].DirectChildren -notcontains $_.DistinguishedName) {
						$global:htGroupTracking[$scanningGroup.Group].DirectChildren.Add($_.DistinguishedName) > $null
					}
				}
			}
			
			$arrGroupsToScan.Remove($scanningGroup) > $null
			
		}
		
		Remove-Variable arrGroupsToScan
	}

	# Find all parents and children.
	Write-Verbose "Looking for all parents and children."
	foreach ($group in $global:htGroupTracking.Keys) {
		foreach ($parent in $global:htGroupTracking[$group].DirectParents) {
			$global:htGroupTracking[$group].AllParents.Add($parent,$null) > $null
			$global:htGroupTracking[$group].AllParentsArray.Add($parent) > $null
			$global:htGroupTracking[$group].AllParents[$parent] = [System.Collections.ArrayList]@()
			$parentsToScan = [System.Collections.ArrayList]@()
			$parentsToScan.Add($parent) > $null
			$discoveredParents = [System.Collections.ArrayList]@()
			while ($parentsToScan) {
				$scanningGroup = $parentsToScan | Select -First 1
				$htGroupTracking[$scanningGroup].DirectParents | Foreach-Object {
					if ($htGroupTracking[$group].AllParents[$parent] -notcontains $_) {
						$htGroupTracking[$group].AllParents[$parent].Add($_) > $null
						$htGroupTracking[$group].AllParentsArray.Add($_) > $null
						if ($discoveredParents -notcontains $_) {
							$parentsToScan.Add($_) > $null
						}
					}
				}
				$discoveredParents.Add($scanningGroup) > $null
				$parentsToScan.Remove($scanningGroup) > $null
			}
		}
		foreach ($child in $global:htGroupTracking[$group].DirectChildren) {
			$global:htGroupTracking[$group].AllChildren.Add($child,$null) > $null
			$global:htGroupTracking[$group].AllChildrenArray.Add($child) > $null
			$global:htGroupTracking[$group].AllChildren[$child] = [System.Collections.ArrayList]@()
			$childrenToScan = [System.Collections.ArrayList]@()
			$childrenToScan.Add($child) > $null
			$discoveredChildren = [System.Collections.ArrayList]@()
			while ($childrenToScan) {
				$scanningGroup = $childrenToScan | Select -First 1
				$htGroupTracking[$scanningGroup].DirectChildren | Foreach-Object {
					if ($htGroupTracking[$group].AllChildren[$child] -notcontains $_) {
						$htGroupTracking[$group].AllChildren[$child].Add($_) > $null
						$htGroupTracking[$group].AllChildrenArray.Add($_) > $null
						if ($discoveredChildren -notcontains $_) {
							$childrenToScan.Add($_) > $null
						}
					}
				}
				$discoveredChildren.Add($scanningGroup) > $null
				$childrenToScan.Remove($scanningGroup) > $null
			}
		}
	}

	# Run loop detection tests.
	Write-Verbose "Running loop detection tests."
	foreach ($group in $global:htGroupTracking.Values) {
		# Check for direct loop.
		$all_parents = $group.AllParents.Keys | Foreach-Object {$group.AllParents[$_]}
		$all_children = $group.AllChildren.Keys | Foreach-Object {$group.AllChildren[$_]}
		if ($group.DirectParents -contains $group.Group -or $group.DirectChildren -contains $group.Group) {
			# Group is looped within itself.
			$obj = NewLoopObject $group.Group
			$arrLoopedGroups.Add($obj) > $null
			Remove-Variable obj
		} elseif ($all_parents -contains $group.Group -or $all_children -contains $group.Group) {
			# Group is looped by way of another group.  Let's figure out why.
			# Look for groups that have the looped group as a parent/child.
			$obj = NewLoopObject $group.Group
			$global:htGroupTracking.Values | Where {$_.Group -ne $group.Group} | Where {$_.AllParentsArray -contains $group.Group -and $_.AllChildrenArray -contains $group.Group} | Foreach-Object {$obj.LoopParticipants.Add($_.Group) > $null}
			$obj.LoopParticipants = $obj.LoopParticipants | Sort
			if ($arrLoopedGroups | Where {$($_.LoopParticipants -join ":") -eq $($obj.LoopParticipants -join ":")}) {
				# Loop already detected, no need to re-add.
			} else {
				$arrLoopedGroups.Add($obj) > $null
			}
			Remove-Variable obj
		}
	}

	#return $arrLoopedGroups

	# Look for loops within loops.
	Write-Verbose "Identifying individual loops."
	foreach ($objLoop in $arrLoopedGroups) {
		if (($objLoop.LoopParticipants | Measure-Object).Count -gt 1) {
			$arrLoopToScan = [System.Collections.ArrayList]@()
			$arrLoop = [System.Collections.ArrayList]@()
			$loop_multiplier = 0
			$global:htGroupTracking[$objLoop.StartingGroup].DirectChildren | Where {$objLoop.LoopParticipants -contains $_} | Foreach-Object {
				$obj = New-Object PSObject -Property @{
					"LoopID" = $(1 + $loop_multiplier);
					"LoopStep" = 1;
					"ParentGroup" = $objLoop.StartingGroup;
					"Group" = $_;
				}
				$arrLoopToScan.Add($obj) > $null
				$loop_multiplier++
			}
			while ($arrLoopToScan) {
				$loop = $arrLoopToScan | Select -First 1
				$loop_multiplier = 0
				$loop_step = $loop.LoopStep + 1
				$children = $global:htGroupTracking[$loop.Group].DirectChildren | Where {$objLoop.LoopParticipants -contains $_}
				foreach ($child in $children) {
					$obj = New-Object PSObject -Property @{
						"LoopID" = $($loop.LoopID + $loop_multiplier);
						"LoopStep" = $loop_step;
						"ParentGroup" = $loop.Group;
						"Group" = $child;
					}
					if ($arrLoop | Where {$_.Group -eq $obj.Group -and $_.ParentGroup -eq $obj.ParentGroup -and $_.LoopID -eq $loop.LoopID}) {
						# This has already been found, no need to scan again.
						$arrLoop.Add($obj) > $null
					} elseif ($child -eq $($arrLoop | Where {$_.LoopID -eq $loop.LoopID -and $_.LoopStep -eq 1}).ParentGroup) {
						$arrLoop.Add($obj) > $null
					} else {
						$arrLoopToScan.Add($obj) > $null
					}
					$loop_multiplier++
					$loop_step = 1
				}
				$arrLoop.Add($loop) > $null
				$arrLoopToScan.Remove($loop) > $null
			}
			$objLoop | Add-Member -MemberType "NoteProperty" -Name "LoopAnalysis" -Value @{}
			$loopIDs = $arrLoop | Foreach-Object {$_.LoopID} | Select -Unique
			foreach ($id in $loopIDs) {
				$objLoop.LoopAnalysis.Add($id,"") > $null
				$arrLoop | Where {$_.LoopID -eq $id} | Sort LoopStep | Foreach-Object {
					$objLoop.LoopAnalysis[$id] = $objLoop.LoopAnalysis[$id] + "Group $($_.ParentGroup) has member $($_.Group).`n"
				}
				$objLoop.LoopAnalysis[$id] = $objLoop.LoopAnalysis[$id].TrimEnd("`n")
			}
		} else {
			# Group is looped in itself.
			$objLoop | Add-Member -MemberType "NoteProperty" -Name "LoopAnalysis" -Value @{1 = "Group $($objLoop.StartingGroup) is a member of itself."}
		}
	}

	return $arrLoopedGroups
}