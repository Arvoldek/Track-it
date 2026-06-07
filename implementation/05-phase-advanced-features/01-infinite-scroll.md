# Phase 5.1: Infinite Scroll Implementation

## Overview

Implement infinite scroll for tracker lists to allow users to create unlimited trackers without pagination.

**Part of**: Phase 5 - Advanced Features
**Duration**: 0.5 day
**Priority**: Medium

## Implementation

### Approach
Use SwiftUI's `ScrollView` with `LazyVStack` for efficient loading. Trackers are loaded in batches as the user scrolls.

### Code Implementation

```swift
// InfiniteScrollView.swift
import SwiftUI

struct InfiniteScrollView<T: Identifiable, Content: View>: View {
    let items: [T]
    let content: (T) -> Content
    let onLoadMore: () -> Void
    let isLoading: Bool
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md.value) {
                ForEach(items) { item in
                    content(item)
                        .id(item.id)
                }
                
                if isLoading {
                    ProgressView()
                        .padding()
                } else {
                    // Trigger loading when this view appears
                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            onLoadMore()
                        }
                }
            }
        }
    }
}

// Usage in TrackerListView
struct TrackerListView: View {
    @StateObject var viewModel: TrackerListViewModel
    
    var body: some View {
        InfiniteScrollView(
            items: viewModel.trackers,
            content: { tracker in
                TrackerCard(tracker: tracker)
            },
            onLoadMore: viewModel.loadMoreTrackers,
            isLoading: viewModel.isLoading
        )
    }
}

// ViewModel with pagination
final class TrackerListViewModel: BaseViewModel {
    private let trackerRepository: TrackerRepositoryProtocol
    
    @Published var trackers: [any BaseTrackerProtocol] = []
    private var currentPage = 0
    private let pageSize = 20
    private var hasMorePages = true
    
    init(trackerRepository: TrackerRepositoryProtocol) {
        self.trackerRepository = trackerRepository
        loadMoreTrackers()
    }
    
    func loadMoreTrackers() {
        guard !isLoading && hasMorePages else { return }
        
        isLoading = true
        
        Task {
            do {
                let newTrackers = try await trackerRepository.getTrackers(
                    page: currentPage,
                    pageSize: pageSize
                )
                
                await MainActor.run {
                    trackers.append(contentsOf: newTrackers)
                    currentPage += 1
                    hasMorePages = newTrackers.count == pageSize
                    isLoading = false
                }
            } catch {
                handleError(error)
            }
        }
    }
}
```

## Core Data Integration

```swift
// TrackerRepositoryProtocol extension
extension TrackerRepositoryProtocol {
    func getTrackers(page: Int, pageSize: Int) async throws -> [any BaseTrackerProtocol] {
        let fetchRequest: NSFetchRequest<TrackerEntity> = TrackerEntity.fetchRequest()
        fetchRequest.fetchLimit = pageSize
        fetchRequest.fetchOffset = page * pageSize
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \TrackerEntity.createdAt, ascending: false)
        ]
        
        let result = try await context.perform {
            let entities = try context.fetch(fetchRequest)
            return entities.compactMap { entity in
                // Convert entity to tracker
                // Implementation depends on tracker type
            }
        }
        
        return result
    }
}
```

## Performance Considerations

1. **Batch Size**: 20-30 items per batch
2. **Prefetching**: Load next batch when 5 items remain
3. **Memory**: Unload items that are far off-screen
4. **Smooth Scrolling**: Use `LazyVStack` for efficient view recycling

## Checklist

- [ ] InfiniteScrollView component created
- [ ] ViewModel pagination logic implemented
- [ ] Core Data batch fetching implemented
- [ ] Performance optimized
- [ ] Tested with large datasets
- [ ] Smooth scrolling verified

---

**Phase**: 5 - Advanced Features  
**Section**: 5.1 - Infinite Scroll  
**Duration**: 0.5 day  
**Status**: Ready for Implementation  
**Dependencies**: Phase 4  
**Last Updated**: [Date]  
**Version**: 1.0
