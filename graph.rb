require 'pqueue'
module Graph
  INFINITY = 1 << 32
  def self.undirected_graph_representation(typed_dependency_list)
    edges = [[]]
    weigths = [[]]
    nodes_by_index = {}
    typed_dependency_list.each{|typed_dep|
      nodes_by_index[typed_dep.dep.index] = typed_dep.dep
      nodes_by_index[typed_dep.gov.index] = typed_dep.gov
      edges[typed_dep.dep.index] ||= []
      edges[typed_dep.dep.index] << typed_dep.gov.index        
      edges[typed_dep.gov.index] ||= []
      edges[typed_dep.gov.index] << typed_dep.dep.index
      
      weigths[typed_dep.dep.index] ||= []
      weigths[typed_dep.dep.index][typed_dep.gov.index] = 1
      weigths[typed_dep.gov.index] ||= []
      weigths[typed_dep.gov.index][typed_dep.dep.index] = 1
      
      typed_dep.dep.parent = typed_dep.gov        
      typed_dep.gov.children = [typed_dep.gov.children, typed_dep.dep].flatten.compact.uniq
    }
    return [edges, weigths, nodes_by_index]
  end
  
  class Dijkstra
    def compute_shortest_path(source, edges, weights, n)
      visited = Array.new(n, false)
      shortest_distances = Array.new(n, INFINITY)
      previous = Array.new(n, nil)
      pq = PQueue.new(proc {|x,y| shortest_distances[x] < shortest_distances[y]})
      
      pq.pop
      pq.push(source)
      visited[source] = true
      shortest_distances[source] = 0      
      while pq.size != 0        
        v = pq.pop
        puts v.to_i
        visited[v] = true        
        if edges[v]        
          edges[v].each do |w|          
            if !visited[w] and shortest_distances[w] > shortest_distances[v] + weights[v][w].to_i
              shortest_distances[w] = shortest_distances[v] + weights[v][w]
              previous[w] = v
              pq.push(w)
            end
          end
        end
      end
      return [shortest_distances, previous]
    end
  end
end