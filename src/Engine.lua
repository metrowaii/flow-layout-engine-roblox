--Services
local CollectionService = game:GetService("CollectionService")

--Folders

--Dependencies
local Flow = require(script.Parent.Parent.Flow)
local Constants = require(script.Parent.Constants)
local FlowProperties = require(script.Parent.FlowProperties)
local LayoutNode = require(script.Parent.LayoutNode)

--Constants
local DEFAULT_VALUES = {
	[FlowProperties.FLEX_DIRECTION] = Flow.FlexDirection.Row,
	[FlowProperties.DIRECTION] = Flow.Direction.LTR,
	[FlowProperties.DISPLAY] = Flow.Display.Flex,
	[FlowProperties.POSITION_TYPE] = Flow.PositionType.Relative,
	[FlowProperties.ALIGN_SELF] = Flow.Align.Auto,
	[FlowProperties.FLEX_BASIS] = "auto",
}
local AUTO = "auto"

--Variables
local connections = {}
local layoutNodesMap = {}
local started = false

--Engine
local Engine = {
	className = "Engine",
}

local function onFlowGuiObjectAdded(flowGuiObject: Instance)
	if not flowGuiObject:IsA("GuiObject") then
		warn("[FlowLayoutEngine] " .. flowGuiObject.Name .. " is not a valid flow node - instance must be a GuiObject")
		return
	end

	local parentInstance = flowGuiObject.Parent
	local parentLayoutNode = nil

	if parentInstance and parentInstance:IsA("GuiObject") then
		parentLayoutNode = layoutNodesMap[parentInstance]
	end

	local layoutNode = LayoutNode.new()

	for _, attributeName in FlowProperties :: { [string]: string } do
		local function onAttributeChanged()
			local value = flowGuiObject:GetAttribute(attributeName) or DEFAULT_VALUES[attributeName]
			layoutNode:setProperty(attributeName, value)
		end

		table.insert(
			layoutNode.Connections,
			flowGuiObject:GetAttributeChangedSignal(attributeName):Connect(onAttributeChanged)
		)

		onAttributeChanged()
	end

	local function onLayoutChanged(computedProperties)
		flowGuiObject.Position = UDim2.fromOffset(computedProperties.left, computedProperties.top)
		flowGuiObject.Size = UDim2.fromOffset(computedProperties.width, computedProperties.height)
	end

	layoutNode:onLayoutChanged(onLayoutChanged)

	onLayoutChanged(layoutNode:getComputedProperties())

	local function onLayoutOrderChanged()
		layoutNode:setOrder(flowGuiObject.LayoutOrder)
	end

	onLayoutOrderChanged()

	table.insert(
		layoutNode.Connections,
		flowGuiObject:GetPropertyChangedSignal("LayoutOrder"):Connect(onLayoutOrderChanged)
	)

	local function onAncestorChanged(child: Instance, parent: Instance?)
		if child == flowGuiObject then
			if parent and parent:IsA("GuiObject") then
				local parentLayoutNode = layoutNodesMap[parent]

				if not parentLayoutNode then
					layoutNode:setParent(nil)
				else
					layoutNode:setParent(parentLayoutNode)
				end
			elseif parent then
				layoutNode:setParent(nil)
			end
		end
	end

	layoutNode:setParent(parentLayoutNode)

	--We defer here to prevent the AncestryChanged event from being fired on initial render
	task.defer(function()
		table.insert(layoutNode.Connections, flowGuiObject.AncestryChanged:Connect(onAncestorChanged))
	end)

	if flowGuiObject:IsA("ScrollingFrame") then
		local function afterLayoutChanged(computedProperties)
			local contentSize = Vector2.new(0, 0)

			for _, child in flowGuiObject:GetChildren() do
				if child:IsA("GuiObject") then
					local farX = child.Position.X.Offset + child.Size.X.Offset
					local farY = child.Position.Y.Offset + child.Size.Y.Offset

					contentSize = Vector2.new(math.max(contentSize.X, farX), math.max(contentSize.Y, farY))
				end
			end

			local baseX = contentSize.X + computedProperties.paddingLeft
			local baseY = contentSize.Y + computedProperties.paddingBottom

			flowGuiObject.CanvasSize = UDim2.fromOffset(baseX, baseY)
		end

		layoutNode:registerAfterLayoutChangedListener(afterLayoutChanged)
	elseif flowGuiObject:IsA("TextLabel") then
		local function onTextBoundsChanged()
			if flowGuiObject:GetAttribute(FlowProperties.WIDTH) == AUTO then
				layoutNode:setProperty(FlowProperties.WIDTH, flowGuiObject.TextBounds.X)
			end

			if flowGuiObject:GetAttribute(FlowProperties.HEIGHT) == AUTO then
				layoutNode:setProperty(FlowProperties.HEIGHT, flowGuiObject.TextBounds.Y)
			end
		end

		table.insert(
			layoutNode.Connections,
			flowGuiObject:GetPropertyChangedSignal("TextBounds"):Connect(onTextBoundsChanged)
		)

		onTextBoundsChanged()
	end

	layoutNodesMap[flowGuiObject] = layoutNode
end

local function onFlowGuiObjectRemoved(flowGuiObject: Instance)
	if not flowGuiObject:IsA("GuiObject") then
		return
	end

	local layoutNode = layoutNodesMap[flowGuiObject]

	if layoutNode then
		layoutNode:destroy()
		layoutNodesMap[flowGuiObject] = nil
	end
end

function Engine.start()
	if started then
		return
	end

	started = true

	table.insert(
		connections,
		CollectionService:GetInstanceAddedSignal(Constants.FLOW_GUI_OBJECT_TAG):Connect(onFlowGuiObjectAdded)
	)

	table.insert(
		connections,
		CollectionService:GetInstanceRemovedSignal(Constants.FLOW_GUI_OBJECT_TAG):Connect(onFlowGuiObjectRemoved)
	)

	for _, flowGuiObject in CollectionService:GetTagged(Constants.FLOW_GUI_OBJECT_TAG) do
		onFlowGuiObjectAdded(flowGuiObject)
	end
end

function Engine.stop()
	if not started then
		return
	end

	for _, connection in connections do
		connection:Disconnect()
	end
	connections = {}

	started = false
end

return Engine
