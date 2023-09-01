local Buffer = {}

local ALIGNMENT_IN_BYTES = 4

function Buffer.GetAlignedSize(unalignedSize)
	if unalignedSize <= 0 then
		return 0
	end

	local numUnalignedBytes = unalignedSize % ALIGNMENT_IN_BYTES
	local numRequiredPaddingBytes = (ALIGNMENT_IN_BYTES - numUnalignedBytes) % ALIGNMENT_IN_BYTES
	local paddedSize = unalignedSize + numRequiredPaddingBytes

	return paddedSize
end

return Buffer
