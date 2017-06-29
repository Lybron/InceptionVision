//
//  ClassifyVideoView.swift
//  DogBreedPrediction
//
//  Created by Jarrod Parkes on 6/15/17.
//  Copyright © 2017 Udacity. All rights reserved.
//

import UIKit

// MARK: - ClassifyVideoView: UIView

class ClassifyVideoView: UIView {
  
  // MARK: Properties
  
  let previewView: UIView = {
    let view = UIView(frame: .zero)
    view.backgroundColor = .red
    return view
  }()
  
  // MARK: Initializer
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .blue
    addSubviews()
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
  // MARK: Setup
  
  func addSubviews() {
    addSubview(previewView)
  }
  
  // MARK: Modify Contents
}
