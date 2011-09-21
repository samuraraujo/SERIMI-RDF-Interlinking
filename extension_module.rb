#Serimi Functionalities.
#It implements extensions in the class String and Array
#Author: Samur Araujo
#Date: 10 september 2011.
#License: SERIMI is distributed under the LGPL[http://www.gnu.org/licenses/lgpl.html] license. 
require "java"
require "simmetrics_jar_v1_6_2_d07_02_07.jar"
 
class Array
  def permutations
    return [self] if size < 2
    perm = []
    each { |e| (self - [e]).permutations.each { |p| perm << ([e] + p) } }
    perm
  end
end
  #################################
class String
  # The extended characters map used by removeaccents. The accented characters 
  # are coded here using their numerical equivalent to sidestep encoding issues.
  # These correspond to ISO-8859-1 encoding.
  ACCENTS_MAPPING = {
    'E' => [200,201,202,203],
    'e' => [232,233,234,235],
    'A' => [192,193,194,195,196,197],
    'a' => [224,225,226,227,228,229,230],
    'C' => [199],
    'c' => [231],
    'O' => [210,211,212,213,214,216],
    'o' => [242,243,244,245,246,248],
    'I' => [204,205,206,207],
    'i' => [236,237,238,239],
    'U' => [217,218,219,220],
    'u' => [249,250,251,252],
    'N' => [209],
    'n' => [241],
    'Y' => [221],
    'y' => [253,255],
    'AE' => [306],
    'ae' => [346],
    'OE' => [188],
    'oe' => [189]
  }
  
  def keyword_normalization()
    
     self.split(" ").map{|x| x.gsub(/\W/," ").gsub(/_/," ").lstrip.rstrip }.join(" ").downcase
     
 end
  def get_similarity(a,b,m)
  java_import "uk.ac.shef.wit.simmetrics.similaritymetrics.QGramsDistance"
  java_import "uk.ac.shef.wit.simmetrics.similaritymetrics.Jaro"
  java_import "uk.ac.shef.wit.simmetrics.similaritymetrics.JaroWinkler"
  java_import "uk.ac.shef.wit.simmetrics.similaritymetrics.Levenshtein"
  java_import "uk.ac.shef.wit.simmetrics.similaritymetrics.MongeElkan"
  java_import "uk.ac.shef.wit.simmetrics.similaritymetrics.SmithWaterman"
  java_import "uk.ac.shef.wit.simmetrics.similaritymetrics.Soundex"
  java_import "uk.ac.shef.wit.simmetrics.similaritymetrics.NeedlemanWunch" 
  if $abbreviate
    a=abbreviate(a)
    b=abbreviate(b)
  end
  if $clean
    a=cleanup(a)
    b=cleanup(b)
  end
  if $reverse
  a=(a).reverse
  b=(b).reverse
  end
  similarity=0
  if  'NGRAM' == m
    metric = QGramsDistance.new()
  similarity =metric.getSimilarity(a, b);
  elsif 'JARO'== m
    metric = Jaro.new()
  similarity =metric.getSimilarity(a, b);
  elsif 'JAROWINKLER'== m
    metric = JaroWinkler.new()
  similarity =metric.getSimilarity(a, b);
  elsif 'LEVENSHTEIN'== m
    metric =  Levenshtein.new()
  similarity =metric.getSimilarity(a, b);
  elsif 'MongeElkan'== m
    metric = MongeElkan.new()
  similarity =metric.getSimilarity(a, b);
  # elsif 'PAIRDISTANCE'== m
  # similarity =a.pair_distance_similar(b)
  # elsif 'SUBSTRING'== m
  # similarity= a.longest_substring_similar(b)
  # elsif 'SUBSEQUENCE'== m
  # similarity= a.longest_subsequence_similar(b)
  elsif 'SMITHWATERMAN'== m
    metric1 =  SmithWaterman .new()
  similarity =metric1.getSimilarity(a, b);
  elsif 'SOUDEX'== m
    metric2 = Soundex .new()
  similarity =metric2.getSimilarity(a, b);
  elsif 'NEEDLEMAN'== m
    metric =  NeedlemanWunch .new()
  similarity =metric.getSimilarity(a, b);
  end
  similarity 
end
 def xmatch(b)
   
  av=0
  # ['JAROWINKLER','LEVENSHTEIN','NGRAM','SMITHWATERMAN','SOUDEX','NEEDLEMAN'].each{|x|
  list=['JAROWINKLER','LEVENSHTEIN','NGRAM' ,'SOUDEX' ]
  list.each{|x|
    
    score = get_similarity( self,b,x)
  
    av= av + score if x != 'SOUDEX' 
    av= av * score if x == 'SOUDEX' 
  }
    av/ (list.size.to_f-1)
  
end
  # Remove the accents from the string. Uses String::ACCENTS_MAPPING as the source map.
  def removeaccents    
    str = String.new(self)
    String::ACCENTS_MAPPING.each {|letter,accents|
      packed = accents.pack('U*')
      rxp = Regexp.new("[#{packed}]", nil, 'U')
      str.gsub!(rxp, letter)
    }
    
    str
  end
  def x_similarity(b)
 
  av=0
  # ['JAROWINKLER','LEVENSHTEIN','NGRAM','SMITHWATERMAN','SOUDEX','NEEDLEMAN'].each{|x|
  list=['JAROWINKLER','LEVENSHTEIN','NGRAM' ,'SOUDEX' ]
  list.each{|x|
    # puts x
    score = get_similarity( a,b,x)
    # puts score
    av= av + score if x != 'SOUDEX' 
    av= av * score if x == 'SOUDEX' 
  }
    av / (list.size.to_f-1)
  
end
  def jarowinkler_similar(str2)
    return  0 if str2 == nil
    str1 = self
    str1.strip!

    str2.strip!

    if str1 == str2
    return 1
    end

    # str2 should be the longer string
    if str1.length > str2.length
    tmp = str2
    str2 = str1
    str1 = tmp
    end

    lmax = str2.length

    # arrays to keep track of positions of matches
    found1 = Array.new(str1.length, false)
    found2 = Array.new(str2.length, false)

    midpoint = ((str1.length / 2) - 1).to_i

    common = 0

    for i in 0..str1.length
      first = 0
      last = 0
      if midpoint >= i
      first = 1
      last = i + midpoint
      else
      first = i - midpoint
      last = i + midpoint
      end

      last = lmax if last > lmax

      for j in first..last
        if str2[j] == str1[i] and found2[j] == false
        common += 1
        found1[i] = true
        found2[j] = true
        break
        end
      end
    end

    last_match = 1
    tr = 0
    for i in 0..found1.length
      if found1[i]
        for j in (last_match..found2.length)
          if found2[j]
          last_match = j + 1
          tr += 0.5 if str1[i] != str2[j]
          end
        end
      end
    end

    onethird = 1.0/3
    if common > 0
      return [(onethird * common / str1.length) +
        (onethird * common / str2.length) +
        (onethird * (common - tr) / common), 1].min
    else
    return 0
    end
  end

end

class Array
  def normalizeNaN()
    self.map!{|a| a.nan? ? 0.0 : a}
  end

  def media()
    self.inject {|sum, n| sum + n } / self.size
  end

  def perm(n = size)
    if size < n or n < 0
      elsif n == 0
      yield([])
      else
        self[1..-1].perm(n - 1) do |x|
        (0...n).each do |i|
            yield(x[0...i] + [first] + x[i..-1])
          end
        end
        self[1..-1].perm(n) do |x|
          yield(x)
        end
      end
  end

  def permutation
    metrics_combination = Array.new
    if self.size > 1
      for i in 1..self.size do
        self.perm(i) do |x| metrics_combination << x.sort{|a,b| a.to_s <=> b.to_s} end
      end
    else
      return [self]
    end
    metrics_combination.uniq!
  end
end 