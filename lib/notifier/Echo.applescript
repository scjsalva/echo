-- Echo's notifier. Echo writes one file per notification into the outbox and
-- launches this app, so macOS shows them with Echo's name and icon. Clicking an
-- Echo notification launches it again with an empty outbox, which opens Echo.
on run
	set base to (POSIX path of (path to application support folder from user domain)) & "Echo/"
	set pending to paragraphs of (do shell script "ls -1 " & quoted form of (base & "outbox") & " 2>/dev/null | sort || true")
	if pending is {} or pending is {""} then
		open location ((do shell script "cat " & quoted form of (base & "base_url") & " 2>/dev/null || echo http://localhost:4848") & "/inbox")
		return
	end if
	repeat with name in pending
		set payload to base & "outbox/" & name
		set fields to paragraphs of (do shell script "cat " & quoted form of payload)
		do shell script "rm -f " & quoted form of payload
		if (count of fields) ≥ 4 then
			if item 4 of fields is "" then
				display notification (item 3 of fields) with title (item 1 of fields) subtitle (item 2 of fields)
			else
				set soundName to item 4 of fields
				if soundName ends with ".aiff" then set soundName to text 1 thru -6 of soundName
				display notification (item 3 of fields) with title (item 1 of fields) subtitle (item 2 of fields) sound name soundName
			end if
		end if
	end repeat
end run
