require 'tempfile'

class ParseTreeGen

    TEMPLATE_FILE = "parse_tree_template.dot"

    def initialize
        read_template
        @node_id = 0
    end

    def read_template
        unless @template
            @template = IO.readlines(TEMPLATE_FILE, '').to_s
        end
    end

    def gen(tree, out = "parse_tree.dot")
        parse_tree = @template
        nodes, edges = get_nodes(tree)
        parse_tree = replace(parse_tree, "$NODES;", nodes)
        parse_tree = replace(parse_tree, "$EDGES;", edges)
        File.open('parse_tree.dot', "w") do |dot_file|
            dot_file.write(parse_tree)
            dot_file.flush
            #parse_tree_img = `dot -Tpng \`cygpath -a --windows #{dot_file.path}\``
            #File.open(out, 'w') {|f| f.write(parse_tree_img) }
        end
    end

    def replace(parse_tree, token, str)
        parse_tree.gsub!(token, str)
    end

    def get_nodes(tree)
        nodes = get_nodes_list(tree, [])
        nodes_str = nodes.inject("") do |s, node|
            rep = node[:node].token_type == :num ? node[:node].value : node[:node].token_type.to_s
            s + "n#{node[:id]} [label=\"#{rep}\"]\n    " 
        end
        edges_str = nodes.inject("") do |s, node| 
            if node[:node].respond_to?(:left)
                s = s + "n#{node[:id]} -> n#{node[:node].left.id};\n    " if node[:node].left
                s = s + "n#{node[:id]} -> n#{node[:node].right.id};\n    " if node[:node].right
            end
            s
        end
        return nodes_str, edges_str
    end

    def get_nodes_list(tree, list)
        if tree
            list = get_nodes_list(tree.left, list) if tree.left
            @node_id += 1
            list.push({:id => @node_id, :node => tree})
            tree.id = @node_id
            list = get_nodes_list(tree.right, list) if tree.right
        end
        list
    end
end
