local Buffer = {}

function Buffer.GetAlignedSize(unalignedSize)
	local size = unalignedSize
	local paddedSize
	if size % 4 == 0 then
		paddedSize = size
	end
	if size % 4 == 1 then
		paddedSize = size + 3
	end
	if size % 4 == 2 then
		paddedSize = size + 2
	end
	if size % 4 == 3 then
		paddedSize = size + 1
	end

	return paddedSize
end

return Buffer
