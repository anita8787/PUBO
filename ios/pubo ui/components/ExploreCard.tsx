
import React from 'react';
import { Post } from '../types';

const ExploreCard: React.FC<{ post: Post }> = ({ post }) => {
  return (
    <div className="min-w-[120px] w-[120px] h-[160px] border-2 border-black rounded-[2rem] overflow-hidden relative snap-start shrink-0 active:scale-[0.98] transition-transform shadow-sm">
      <img src={post.image} alt={post.content} className="w-full h-full object-cover" />
      <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent" />
      
      <div className="absolute bottom-4 left-4 right-4">
        <p className="text-white font-black text-sm leading-tight drop-shadow-md tracking-tight">{post.tags[0] || 'Travel'}</p>
      </div>
    </div>
  );
};

export default ExploreCard;
