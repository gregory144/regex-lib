require 'tempfile'
require 'set'

require 'node'

module Regex

    class GraphGen

        PARSE_TREE_TEMPLATE_FILE = "templates/parse_tree_template.dot"
        NFA_TEMPLATE_FILE = "templates/nfa_template.dot"

        class << self
            def read_template(template_file)
                IO.readlines(template_file, '').to_s
            end

            def gen(tree, out = "parse_tree.dot")
                tree = Regex::Parser(tree) unless tree.respond_to?(:operands)
                gen_file(out, PARSE_TREE_TEMPLATE_FILE, get_nodes(tree))
            end

            def gen_nfa(nfa, out = "nfa.dot")
                nfa = Regex::NFA.construct(Regex::Parser.parse_tree(nfa)) unless nfa.respond_to?(:transitions)
                gen_file(out, NFA_TEMPLATE_FILE, get_states(nfa))
            end

            def gen_file(file, template, nodes_and_edges)
                graph = read_template(template)
                nodes, edges = nodes_and_edges
                graph = replace(graph, "$NODES;", nodes)
                graph = replace(graph, "$EDGES;", edges)
                puts "Graph:\n#{graph}"
                File.open(file, "w") do |dot_file|
                    dot_file.write(graph)
                    dot_file.flush
                    #parse_tree_img = `dot -Tpng \`cygpath -a --windows #{dot_file.path}\``
                    #File.open(out, 'w') {|f| f.write(parse_tree_img) }
                end
            end

            def replace(parse_tree, token, str)
                parse_tree.gsub!(token, str)
            end

            def get_states(nfa)
                nodes_str = ""
                edges_str = ""
                states = Set.new
                edges = []
                nfa.transitions.each do |k, v|
                    start, symbol = k
                    states << start
                    v.each do |finish| 
                        states << finish
                        edges << [start, finish, symbol] 
                    end
                end
                states.each do |node|
                    accept = node == nfa.accept ? ", shape=\"doublecircle\"" : ""
                    nodes_str << "n#{node} [label=\"#{node}\"#{accept}]\n    " 
                end
                edges.each do |edge|
                    start, finish, symbol = edge
                    symbol ||= "&#949;" 
                    edges_str << "n#{start} -> n#{finish} [label=\"#{symbol}\"];\n    " 
                end
                return nodes_str, edges_str
            end

            def get_nodes(tree)
                nodes = get_nodes_list(tree, [])
                nodes_str = nodes.inject("") do |s, node|
                    rep = node[:node].token_type == :simple ? node[:node].value : node[:node].token_type.to_s
                    s + "n#{node[:id]} [label=\"#{rep}\"]\n    " 
                end
                edges_str = nodes.inject("") do |s, node| 
                    if node[:node].respond_to?(:operands)
                        node[:node].operands.each do |operand|
                        s = s + "n#{node[:id]} -> n#{operand.id};\n    " if operand
                        end
                    end
                    s
                end
                return nodes_str, edges_str
            end

            def get_nodes_list(tree, list)
                if tree
                    list.push({:id => list.size+1, :node => tree})
                    tree.id = list.size
                    tree.operands.each do |operand|
                        list = get_nodes_list(operand, list)
                    end
                end
                list
            end
        end
    end

end
