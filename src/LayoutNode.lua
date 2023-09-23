--Services

--Folders

--Dependencies
local FlowProperties = require(script.Parent.FlowProperties)
local Flow = require(script.Parent.Parent.Flow)

--Constants

--Variables

--Types
type ComputedProperties = {
	left: number,
	top: number,
	width: number,
	height: number,
	paddingLeft: number,
	paddingRight: number,
	paddingTop: number,
	paddingBottom: number,
}
type LayoutNode = {
	Connections: { [number]: RBXScriptConnection },
	onLayoutChanged: (self: LayoutNode, callback: (computedProperties: ComputedProperties) -> ()) -> () -> (),
	registerAfterLayoutChangedListener: (
		self: LayoutNode,
		callback: (computedProperties: ComputedProperties) -> ()
	) -> () -> (),
	setProperty: (self: LayoutNode, propertyName: string, value: any) -> (),
	setParent: (self: LayoutNode, parentNode: LayoutNode?) -> (),
	recalculateLayout: (self: LayoutNode) -> (),
	destroy: (self: LayoutNode) -> (),
	addChild: (self: LayoutNode, child: LayoutNode, index: number?) -> (),
	removeChild: (self: LayoutNode, child: LayoutNode) -> (),
	getComputedProperties: (self: LayoutNode) -> ComputedProperties,
	getFlowNode: (self: LayoutNode) -> Flow.node,
	setOrder: (self: LayoutNode, order: number) -> (),
	getOrder: (self: LayoutNode) -> number,
	_direction: number,
	_layoutChangedListeners: { [number]: (computedProperties: ComputedProperties) -> any? },
	_afterLayoutChangedListeners: { [number]: (computedProperties: ComputedProperties) -> any? },
	_node: Flow.node,
	_parentNode: LayoutNode?,
	_triggerLayoutChanged: (self: LayoutNode) -> (),
	_children: { [number]: LayoutNode },
	_order: number,
	new: () -> LayoutNode,
}

--Local Functions
local function isPaddingProperty(propertyName)
	return propertyName == FlowProperties.PADDING_BOTTOM
		or propertyName == FlowProperties.PADDING_LEFT
		or propertyName == FlowProperties.PADDING_RIGHT
		or propertyName == FlowProperties.PADDING_TOP
end

local function isMarginProperty(propertyName)
	return propertyName == FlowProperties.MARGIN_BOTTOM
		or propertyName == FlowProperties.MARGIN_LEFT
		or propertyName == FlowProperties.MARGIN_RIGHT
		or propertyName == FlowProperties.MARGIN_TOP
end

local function isBorderProperty(propertyName)
	return propertyName == FlowProperties.BORDER_BOTTOM
		or propertyName == FlowProperties.MARGIN_LEFT
		or propertyName == FlowProperties.MARGIN_RIGHT
		or propertyName == FlowProperties.MARGIN_TOP
end

local function isPositionProperty(propertyName)
	return propertyName == FlowProperties.LEFT
		or propertyName == FlowProperties.RIGHT
		or propertyName == FlowProperties.TOP
		or propertyName == FlowProperties.BOTTOM
end

local function isBottomProperty(propertyName)
	return propertyName == FlowProperties.PADDING_BOTTOM
		or propertyName == FlowProperties.MARGIN_BOTTOM
		or propertyName == FlowProperties.BORDER_BOTTOM
		or propertyName == FlowProperties.BOTTOM
end

local function isTopProperty(propertyName)
	return propertyName == FlowProperties.PADDING_TOP
		or propertyName == FlowProperties.MARGIN_TOP
		or propertyName == FlowProperties.BORDER_TOP
		or propertyName == FlowProperties.TOP
end

local function isLeftProperty(propertyName)
	return propertyName == FlowProperties.PADDING_LEFT
		or propertyName == FlowProperties.MARGIN_LEFT
		or propertyName == FlowProperties.BORDER_LEFT
		or propertyName == FlowProperties.LEFT
end

local function isRightProperty(propertyName)
	return propertyName == FlowProperties.PADDING_RIGHT
		or propertyName == FlowProperties.MARGIN_RIGHT
		or propertyName == FlowProperties.BORDER_RIGHT
		or propertyName == FlowProperties.RIGHT
end

local function getEdgeFromProperty(propertyName)
	if isBottomProperty(propertyName) then
		return Flow.Edge.Bottom
	elseif isLeftProperty(propertyName) then
		return Flow.Edge.Left
	elseif isRightProperty(propertyName) then
		return Flow.Edge.Right
	elseif isTopProperty(propertyName) then
		return Flow.Edge.Top
	end
	return Flow.Edge.All
end

--LayoutNode
local LayoutNodeMeta = {
	ClassName = "LayoutNode",
}
LayoutNodeMeta.__index = LayoutNodeMeta

local LayoutNode: LayoutNode = LayoutNodeMeta :: any

function LayoutNode.new()
	local self: LayoutNode = setmetatable({}, LayoutNode) :: any

	--Public--
	self.Connections = {}

	--Private--
	self._layoutChangedListeners = {}
	self._afterLayoutChangedListeners = {}
	self._node = Flow.Node.new()
	self._parentNode = nil
	self._direction = Flow.Direction.LTR
	self._children = {}
	self._order = 0

	--Init--

	return self
end

function LayoutNode:onLayoutChanged(callback)
	table.insert(self._layoutChangedListeners, callback)

	return function()
		local index = table.find(self._layoutChangedListeners, callback)

		if index then
			table.remove(self._layoutChangedListeners, index)
		end
	end
end

function LayoutNode:registerAfterLayoutChangedListener(callback)
	table.insert(self._afterLayoutChangedListeners, callback)

	return function()
		local index = table.find(self._afterLayoutChangedListeners, callback)

		if index then
			table.remove(self._afterLayoutChangedListeners, index)
		end
	end
end

function LayoutNode:addChild(child)
	--TO-DO: Implement proper layout order handling
	self._node:insertChild(child:getFlowNode(), self._node:getChildCount() + 1)
	table.insert(self._children, child)
	self:recalculateLayout()
end

function LayoutNode:removeChild(child)
	local index = table.find(self._children, child)
	if index then
		self._node:removeChild(child:getFlowNode())
		table.remove(self._children, index)
		self:recalculateLayout()
	end
end

function LayoutNode:getOrder()
	return self._order
end

function LayoutNode:setOrder(order)
	self._order = order
end

function LayoutNode:setParent(parentNode)
	if self._parentNode then
		self._parentNode:removeChild(self)
	end
	self._parentNode = parentNode
	if parentNode then
		parentNode:addChild(self)
	else
		self:recalculateLayout()
	end
end

function LayoutNode:recalculateLayout()
	if self._parentNode then
		self._parentNode:recalculateLayout()
	else
		self._node:calculateLayout(nil, nil, self._direction)
	end
	self:_triggerLayoutChanged()
end

function LayoutNode:setProperty(propertyName, value)
	if propertyName == FlowProperties.WIDTH then
		self._node:setWidth(value)
	elseif propertyName == FlowProperties.HEIGHT then
		self._node:setHeight(value)
	elseif propertyName == FlowProperties.MIN_HEIGHT then
		self._node:setMinHeight(value)
	elseif propertyName == FlowProperties.MIN_WIDTH then
		self._node:setMinWidth(value)
	elseif propertyName == FlowProperties.MAX_HEIGHT then
		self._node:setMaxHeight(value)
	elseif propertyName == FlowProperties.MAX_WIDTH then
		self._node:setMaxWidth(value)
	elseif propertyName == FlowProperties.FLEX_DIRECTION then
		self._node:setFlexDirection(value)
	elseif propertyName == FlowProperties.DIRECTION then
		self._direction = value
	elseif propertyName == FlowProperties.FLEX_GROW then
		self._node:setFlexGrow(value)
	elseif propertyName == FlowProperties.FLEX_SHRINK then
		self._node:setFlexShrink(value)
	elseif propertyName == FlowProperties.POSITION_TYPE then
		self._node:setPositionType(value)
	elseif propertyName == FlowProperties.FLEX_WRAP then
		self._node:setFlexWrap(value)
	elseif propertyName == FlowProperties.FLEX_BASIS then
		if typeof(value) == "string" and value == "auto" then
			self._node:setFlexBasisAuto()
		else
			self._node:setFlexBasis(value)
		end
	elseif propertyName == FlowProperties.ALIGN_CONTENT then
		self._node:setAlignContent(value)
	elseif propertyName == FlowProperties.JUSTIFY_CONTENT then
		self._node:setJustifyContent(value)
	elseif propertyName == FlowProperties.ALIGN_ITEMS then
		self._node:setAlignItems(value)
	elseif propertyName == FlowProperties.ALIGN_SELF then
		self._node:setAlignSelf(value)
	elseif propertyName == FlowProperties.DISPLAY then
		self._node:setDisplay(value)
	elseif isPositionProperty(propertyName) then
		local edge = getEdgeFromProperty(propertyName)
		self._node:setPosition(edge, value)
	elseif isPaddingProperty(propertyName) then
		local edge = getEdgeFromProperty(propertyName)
		self._node:setPadding(edge, value)
	elseif isMarginProperty(propertyName) then
		local edge = getEdgeFromProperty(propertyName)
		self._node:setMargin(edge, value)
	elseif isBorderProperty(propertyName) then
		local edge = getEdgeFromProperty(propertyName)
		self._node:setBorder(edge, value)
	end
	self:recalculateLayout()
end

function LayoutNode:getComputedProperties()
	return {
		left = self._node:getComputedLeft(),
		top = self._node:getComputedTop(),
		right = self._node:getComputedRight(),
		width = self._node:getComputedWidth(),
		height = self._node:getComputedHeight(),
		paddingLeft = self._node:getComputedPadding(Flow.Edge.Left),
		paddingRight = self._node:getComputedPadding(Flow.Edge.Right),
		paddingTop = self._node:getComputedPadding(Flow.Edge.Top),
		paddingBottom = self._node:getComputedPadding(Flow.Edge.Bottom),
	}
end

function LayoutNode:getFlowNode()
	return self._node
end

function LayoutNode:_triggerLayoutChanged()
	local computedProperties = self:getComputedProperties()
	for _, callbackFn in self._layoutChangedListeners do
		callbackFn(computedProperties)
	end
	for _, child in self._children do
		child:_triggerLayoutChanged()
	end
	for _, callbackFn in self._afterLayoutChangedListeners do
		callbackFn(computedProperties)
	end
end

function LayoutNode:destroy()
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	self.Connections = {}
	self._layoutChangedListeners = {}
	if self._parentNode then
		self._parentNode:removeChild(self)
	end
	self._node:free()
	self._node:freeRecursive()
end

return LayoutNode
