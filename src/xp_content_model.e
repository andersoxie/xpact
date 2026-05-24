note
	description: "DTD element content model node."

class
	XP_CONTENT_MODEL

create
	make

feature {NONE} -- Initialization

	make (a_type, a_quant: INTEGER; a_name: detachable READABLE_STRING_8)
			-- Create content model node.
		require
			valid_type: is_valid_type (a_type)
			valid_quant: is_valid_quant (a_quant)
		do
			content_type := a_type
			quantifier := a_quant
			if attached a_name as l_name then
				create name.make_from_string (l_name)
			end
			create children.make (2)
		ensure
			type_set: content_type = a_type
			quantifier_set: quantifier = a_quant
			children_attached: children /= Void
		end

feature -- Expat-compatible constants

	Type_empty: INTEGER = 1

	Type_any: INTEGER = 2

	Type_mixed: INTEGER = 3

	Type_name: INTEGER = 4

	Type_choice: INTEGER = 5

	Type_sequence: INTEGER = 6

	Quant_none: INTEGER = 0

	Quant_optional: INTEGER = 1

	Quant_repetition: INTEGER = 2

	Quant_plus: INTEGER = 3

feature -- Access

	content_type: INTEGER
			-- Expat `XML_Content.type' value.

	quantifier: INTEGER
			-- Expat `XML_Content.quant' value.

	name: detachable STRING_8
			-- Name for `Type_name' nodes.

	children: ARRAYED_LIST [XP_CONTENT_MODEL]
			-- Child content model nodes.

	node_count: INTEGER
			-- Count this node and all descendants.
		local
			i: INTEGER
		do
			Result := 1
			from
				i := 1
			invariant
				index_in_bounds: i >= 1 and i <= children.count + 1
			until
				i > children.count
			loop
				Result := Result + children.i_th (i).node_count
				i := i + 1
			variant
				children.count - i + 1
			end
		ensure
			positive: Result >= 1
		end

feature -- Element change

	add_child (a_child: XP_CONTENT_MODEL)
			-- Append child node.
		require
			child_attached: a_child /= Void
		do
			children.extend (a_child)
		ensure
			one_more: children.count = old children.count + 1
		end

	set_quantifier (a_quant: INTEGER)
			-- Set node quantifier.
		require
			valid_quant: is_valid_quant (a_quant)
		do
			quantifier := a_quant
		ensure
			quantifier_set: quantifier = a_quant
		end

feature -- Validation

	is_valid_type (a_type: INTEGER): BOOLEAN
			-- Is `a_type' an Expat content model type?
		do
			Result := a_type >= Type_empty and a_type <= Type_sequence
		end

	is_valid_quant (a_quant: INTEGER): BOOLEAN
			-- Is `a_quant' an Expat content model quantifier?
		do
			Result := a_quant >= Quant_none and a_quant <= Quant_plus
		end

invariant
	valid_type: is_valid_type (content_type)
	valid_quantifier: is_valid_quant (quantifier)
	children_attached: children /= Void

end
